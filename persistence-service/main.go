package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/RishangS/auth-service/utils"
	"github.com/segmentio/kafka-go"
)

func main() {
	// Initialize database connection
	db := utils.NewDBService()

	// Get Kafka configuration from environment
	kafkaBrokers := getEnv("KAFKA_BROKERS", "localhost:9092")
	kafkaTopic := getEnv("KAFKA_TOPIC", "persist")
	kafkaGroupID := getEnv("KAFKA_GROUP_ID", "persistence-group")

	// Create Kafka reader for persist topic
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:  []string{kafkaBrokers},
		Topic:    kafkaTopic,
		GroupID:  kafkaGroupID,
		MinBytes: 10e3, // 10KB
		MaxBytes: 10e6, // 10MB
		MaxWait:  1 * time.Second,
	})
	defer reader.Close()

	log.Printf("Persistence service started. Listening for messages on topic: %s", kafkaTopic)

	for {
		msg, err := reader.ReadMessage(context.Background())
		if err != nil {
			log.Printf("Error reading message: %v", err)
			continue
		}

		// Process and persist the message
		if err := processAndPersist(db, msg); err != nil {
			log.Printf("Error processing message: %v", err)
		}
	}
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// processAndPersist handles the complete message processing pipeline
func processAndPersist(db *utils.UserRepository, msg kafka.Message) error {
	// Parse message metadata from headers
	metadata, err := extractMessageMetadata(msg)
	if err != nil {
		return err
	}

	// Create message in database
	if _, err := db.CreateMessage(metadata.From, metadata.To, string(msg.Value)); err != nil {
		return fmt.Errorf("error creating message: %w", err)
	}

	log.Printf("Persisted message from %s to %s", metadata.From, metadata.To)
	return nil
}

// MessageMetadata contains extracted message information
type MessageMetadata struct {
	From      string    `json:"from"`
	To        string    `json:"to"`
	Timestamp time.Time `json:"timestamp"`
}

// extractMessageMetadata extracts metadata from Kafka message headers
func extractMessageMetadata(msg kafka.Message) (*MessageMetadata, error) {
	metadata := &MessageMetadata{}

	for _, header := range msg.Headers {
		switch header.Key {
		case "From":
			metadata.From = string(header.Value)
		case "To":
			metadata.To = string(header.Value)
		case "Timestamp":
			t, err := time.Parse(time.RFC3339, string(header.Value))
			if err != nil {
				return nil, fmt.Errorf("invalid timestamp format: %w", err)
			}
			metadata.Timestamp = t
		}
	}

	// Validate required fields
	if metadata.From == "" || metadata.To == "" {
		return nil, fmt.Errorf("missing required message headers")
	}

	// Set current time if timestamp not provided
	if metadata.Timestamp.IsZero() {
		metadata.Timestamp = time.Now()
	}

	return metadata, nil
}
