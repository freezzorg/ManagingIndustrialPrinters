package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	cmds "github.com/freezzorg/printcomm/internal/commands"
	db "github.com/freezzorg/printcomm/internal/database"
	"github.com/freezzorg/printcomm/internal/inits"
	"github.com/freezzorg/printcomm/internal/models"
	prn "github.com/freezzorg/printcomm/internal/mprinter"
	resp "github.com/freezzorg/printcomm/internal/response"
)

var (
	logger    *inits.Logger
	validator *inits.ValidatorWrapper
	config    *inits.Config
	printer   *prn.Printer
	cmdProc   *cmds.CommandProcessor
	respProc  *resp.ResponseProcessor
)

// Структуры для работы с запросами
type (
	CMD struct {
		CmdType string `json:"cmdtype" validate:"required"`
	}

	SendCmdToPrinter struct {
		CmdName string `json:"cmdname" validate:"required"`
		CmdBody string `json:"cmdbody,omitempty"`
		UIDLine string `json:"uidline,omitempty" validate:"omitempty,len=36"`
		RMLine  string `json:"rmline,omitempty" validate:"omitempty,max=9"`
	}

	RequestToDB struct {
		CmdName string `json:"cmdname" validate:"required"`
		CmdBody string `json:"cmdbody,omitempty"`
	}

	Response struct {
		Response interface{} `json:"response,omitempty"`
		Error    string      `json:"error,omitempty"`
	}
)

// processCommand обрабатывает входящую команду от клиента и возвращает результат или ошибку
func processCommand(cmdType string, body []byte) (interface{}, error) {
	switch cmdType {
	case "sendcmdtoprinter":
		return processPrinterCommand(body)
	case "requesttodb":
		return processDBRequest(body)
	case "":
		return nil, errors.New("SENDCOMMAND: 'processCommand'. Команда не указана")
	default:
		return nil, fmt.Errorf("SENDCOMMAND: 'processCommand'. Команда не распознана: 'cmdtype: %s'", cmdType)
	}
}

// processPrinterCommand обрабатывает команды для принтера
func processPrinterCommand(body []byte) (interface{}, error) {
	cmd := new(SendCmdToPrinter)
	if err := validator.ValidatedUnmarshal(body, cmd); err != nil {
		return nil, fmt.Errorf("SENDCMDTOPRINT: 'processPrinterCommand'. Ошибка при декодировании команды принтера: %w", err)
	}

	logger.Debug.Println("SENDCMDTOPRINT: 'processPrinterCommand'. Сообщение для принтера:", cmd.CmdBody)

	bytesCmd, err := cmdProc.Commands(cmd.CmdName, cmd.CmdBody)
	if err != nil {
		return nil, err
	}

	printerInstance, err := db.GetPrinter(cmd.UIDLine)
	if err != nil {
		return nil, err
	}

	if printerInstance.Status != int(models.InTheWork) {
		msg := "SENDCMDTOPRINT: 'processPrinterCommand'. Не найден принтер со статусом 'В работе'"
		if cmd.RMLine != "" {
			msg += fmt.Sprintf(" для линии %s", cmd.RMLine)
		}
		return nil, errors.New(msg)
	}

	bytesReq, err := printer.SendDataToPrinter(printerInstance.IP+":"+printerInstance.Port, bytesCmd)
	if err != nil {
		return nil, err
	}

	// Используем ResponseProcessor вместо прямого вызова resp.Commands
	cmdJSON, err := respProc.Commands(false, cmd.CmdName, bytesReq)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}
	if err := json.Unmarshal(cmdJSON, &result); err != nil {
		return nil, fmt.Errorf("SENDCMDTOPRINT: 'processPrinterCommand'. Ошибка при декодировании ответа от принтера: %w", err)
	}

	return result["response"], nil
}

// processDBRequest обрабатывает запросы к базе данных
func processDBRequest(body []byte) (interface{}, error) {
	req := new(RequestToDB)
	if err := validator.ValidatedUnmarshal(body, req); err != nil {
		return nil, fmt.Errorf("REQUESTTODB: Ошибка при декодировании запроса к БД: %w", err)
	}

	logger.Debug.Println("REQUESTTODB: Команда запроса в базу данных:", req.CmdName, req.CmdBody)

	switch req.CmdName {
	case "GetPrinter":
		return handleGetPrinter(req.CmdBody)
	case "GetAllPrinters":
		return handleGetAllPrinters()
	case "PutPrinter":
		return handlePutPrinter(req.CmdBody)
	case "PutManyPrinters":
		return nil, handlePutMayPrinters(req.CmdBody)
	case "UpdPrinter":
		return handleUpdPrinter(req.CmdBody)
	case "DelPrinter":
		return handleDelPrinter(req.CmdBody)
	case "RemoveAllPrinters":
		return nil, handleRemoveAll()
	default:
		return nil, errors.New("REQUESTTODB: Команда запроса в базу данных не распознана")
	}
}

func handleGetPrinter(data string) (interface{}, error) {
	type tGetPrinter struct {
		UID string `json:"uid,omitempty" validate:"excludesall=ID"` // UID, если используется
		ID  uint64 `json:"id,omitempty" validate:"excludesall=UID"` // ID, если используется
	}

	dataFind := new(tGetPrinter)
	if err := validator.ValidatedUnmarshal([]byte(data), dataFind); err != nil {
		return nil, fmt.Errorf("REQUESTTODB: 'handleGetPrinter'. Ошибка чтения JSON-данных: %w", err)
	}

	// Проверяем, какой из параметров задан, и вызываем db.GetPrinter с соответствующим типом
	switch {
	case dataFind.UID != "":
		return db.GetPrinter(dataFind.UID)
	case dataFind.ID != 0:
		return db.GetPrinter(dataFind.ID)
	default:
		return nil, errors.New("REQUESTTODB: 'handleGetPrinter'. должен быть указан либо 'uid', либо 'id'")
	}
}

func handleGetAllPrinters() (interface{}, error) {
	return db.GetAllPrinters()
}

func handlePutPrinter(data string) (interface{}, error) {
	return db.PutPrinter(data)
}

func handlePutMayPrinters(data string) error {
	return db.PutManyPrinters(data)
}

func handleUpdPrinter(data string) (interface{}, error) {
	changeData := new(models.Printer)
	if err := validator.ValidatedUnmarshal([]byte(data), changeData); err != nil {
		return nil, fmt.Errorf("REQUESTTODB: 'handleUpdPrinter'. Ошибка чтения JSON-данных: %w", err)
	}
	return db.UpdPrinter(changeData)
}

func handleDelPrinter(data string) (interface{}, error) {
	type tDelPrinter struct {
		ID uint64 `json:"id" validate:"required"`
	}
	dataID := new(tDelPrinter)
	if err := validator.ValidatedUnmarshal([]byte(data), dataID); err != nil {
		return nil, fmt.Errorf("REQUESTTODB: 'handleDelPrinter'. Ошибка чтения JSON-данных: %w", err)
	}
	return db.DelPrinter(dataID.ID)
}

func handleRemoveAll() error {
	return db.RemoveAllPrinters()
}

// defaultHandler обрабатывает входящие HTTP-запросы
func defaultHandler(w http.ResponseWriter, r *http.Request) {
	const requestTimeout = 3 * time.Second
	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	w.Header().Set("Content-Type", "application/json")

	body, err := io.ReadAll(r.Body)
	defer r.Body.Close()
	if err != nil {
		sendResponse(w, http.StatusBadRequest, Response{}, fmt.Errorf("MAIN: 'defaultHandler'. Ошибка при чтении запроса: %w", err))
		return
	}

	select {
	case <-ctx.Done():
		sendResponse(w, http.StatusRequestTimeout, Response{}, fmt.Errorf("MAIN: 'defaultHandler'. Операция прервана: %w", ctx.Err()))
		return
	default:
		switch r.Method {
		case http.MethodGet:
			message := "GET: Home page"
			logger.Info.Println(message)
			sendResponse(w, http.StatusOK, Response{Response: message}, nil)

		case http.MethodPost:
			cmd := new(CMD)
			if err := validator.ValidatedUnmarshal(body, cmd); err != nil {
				sendResponse(w, http.StatusBadRequest, Response{}, fmt.Errorf("MAIN: 'defaultHandler'. Ошибка при декодировании JSON: %w", err))
				return
			}

			result, err := processCommand(cmd.CmdType, body)
			if err != nil {
				sendResponse(w, http.StatusBadRequest, Response{}, err)
				return
			}
			sendResponse(w, http.StatusOK, Response{Response: result}, nil)

		default:
			sendResponse(w, http.StatusMethodNotAllowed, Response{}, errors.New("MAIN: 'defaultHandler'. Метод не поддерживается"))
		}
	}
}

// sendResponse отправляет JSON-ответ с результатом или ошибкой
func sendResponse(w http.ResponseWriter, statusCode int, response Response, err error) {
	if err != nil {
		logger.Error.Println(err)
		response = Response{Error: err.Error()} // Перезаписываем response, если есть ошибка
	}
	w.WriteHeader(statusCode)
	if encodeErr := json.NewEncoder(w).Encode(response); encodeErr != nil {
		logger.Error.Println("MAIN: 'sendResponse'. Ошибка отправки JSON-ответа:", encodeErr)
	}
}

// setupServer конфигурирует и возвращает HTTP-сервер
func setupServer(backupManager *db.BackupManager) *http.Server {
	mux := http.NewServeMux()
	mux.HandleFunc("/", defaultHandler)

	mux.HandleFunc("/backup", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "BACKUP: 'setupServer'. Метод не поддерживается", http.StatusMethodNotAllowed)
			return
		}

		if err := backupManager.PerformBackup(); err != nil {
			logger.Error.Println("BACKUP: 'setupServer'. Ошибка при выполнении ручного бэкапа:", err)
			http.Error(w, "BACKUP: 'setupServer'. Ошибка при создании ручного бэкапа", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("BACKUP: 'setupServer'. Бэкап успешно создан"))
	})

	if config.WsHostPort == "" {
		logger.Fatal("MAIN: 'setupServer'. Ошибка: адрес сервера (WsHostPort) не задан")
	}

	return &http.Server{
		Addr:    config.WsHostPort,
		Handler: mux,
	}
}

// initBackupManager создаёт и настраивает менеджер бэкапов
func initBackupManager(logger *inits.Logger) (*db.BackupManager, error) {
	backupConfig := db.BackupConfig{
		DbDir:        config.BackupConf.DB,
		BackupDir:    config.BackupConf.Directory,
		Schedule:     config.BackupConf.Schedule,
		MaxBackups:   config.BackupConf.MaxCount,
		CompressData: config.BackupConf.Compress,
	}

	backupManager, err := db.NewBackupManager(backupConfig, logger)
	if err != nil {
		return nil, fmt.Errorf("MAIN: 'initBackupManager'. Ошибка создания менеджера бэкапов: %w", err)
	}

	if err := backupManager.StartScheduledBackups(); err != nil {
		return nil, fmt.Errorf("MAIN: 'initBackupManager'. Ошибка запуска планировщика бэкапов: %w", err)
	}

	return backupManager, nil
}

func main() {
	var err error
	config, err = inits.InitConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "MAIN: Ошибка инициализации конфигурации: %v\n", err)
		os.Exit(1)
	}

	logger, err = inits.NewLogger(config.LogLevel, config.LogFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "MAIN: Ошибка инициализации логгера: %v\n", err)
		os.Exit(1)
	}

	validator, err = inits.NewValidator(logger, config.LogLevel == "DEBUG")
	if err != nil {
		logger.Error.Println("MAIN: Ошибка инициализации валидатора:", err)
		os.Exit(1)
	}

	printer = prn.NewPrinter(logger, 1*time.Second)
	cmdProc = cmds.NewCommandProcessor(logger, validator)
	respProc = resp.NewResponseProcessor(logger)

	if err := db.InitDatabase(logger, validator); err != nil {
		logger.Error.Println("MAIN: Ошибка инициализации базы данных:", err)
		os.Exit(1)
	}
	defer db.CloseDatabase()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	backupManager, err := initBackupManager(logger)
	if err != nil {
		logger.Error.Println("MAIN: Ошибка инициализации менеджера бэкапов:", err)
	} else {
		defer backupManager.Stop()
		if err := backupManager.PerformBackup(); err != nil {
			logger.Error.Println("MAIN: Не удалось создать начальный бэкап:", err)
		}
	}

	server := setupServer(backupManager)
	go func() {
		logger.Info.Println("MAIN: HTTP-сервер запущен на интерфейсе:", config.WsHostPort)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error.Println("MAIN: Ошибка запуска HTTP-сервера:", err)
		}
	}()

	<-stop
	logger.Info.Println("MAIN: Получен сигнал завершения, останавливаем сервер...")

	logger.Info.Println("MAIN: Создание финального бэкапа перед завершением...")
	if backupManager != nil {
		if err := backupManager.PerformBackup(); err != nil {
			logger.Error.Println("MAIN: Ошибка при создании финального бэкапа:", err)
		}
	}

	const shutdownTimeout = 5 * time.Second
	shutdownCtx, shutdownCancel := context.WithTimeout(ctx, shutdownTimeout)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error.Println("MAIN: Ошибка завершения работы сервера:", err)
	}

	if err := logger.Close(); err != nil {
		logger.Error.Println("MAIN: Ошибка при очистке ресурсов:", err)
	}
	logger.Info.Println("MAIN: Сервер завершил работу")
}