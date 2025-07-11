# golang-assignment

How to test: 

System Requirements : Ubuntu/Mac shell, Golang, Kubectl, minikube, docker, postman

Step 1: 
Open ubuntu shell and start mini kube 
       minikube start
       eval $(minikube docker-env)

Step 2: 
    run below command to start all services 
    ./k8s/deploy.sh

    To kill all services and cleanup 
    ./k8s/cleanup.sh


Step 3: 
Port forward and Login into Postgres and create below tables
                
                kubectl port-forward -n messaging-app service/postgres 5432:5432
                
                
                CREATE TABLE users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(255) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    email VARCHAR(255) UNIQUE NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    is_active BOOLEAN NOT NULL DEFAULT TRUE
                );

                -- Create indexes for better performance on lookups
                CREATE INDEX idx_users_username ON users(username);
                CREATE INDEX idx_users_email ON users(email);

                CREATE OR REPLACE FUNCTION update_updated_at_column()
                RETURNS TRIGGER AS $$
                BEGIN
                    NEW.updated_at = CURRENT_TIMESTAMP;
                    RETURN NEW;
                END;
                $$ LANGUAGE plpgsql;

                CREATE TRIGGER update_users_updated_at
                BEFORE UPDATE ON users
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();


                ALTER TABLE users ADD CONSTRAINT email_check CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$');


                ALTER TABLE users ADD CONSTRAINT username_check CHECK (username ~* '^[a-zA-Z0-9_]+$');



                -- messages.sql
                CREATE TABLE messages (
                    id SERIAL PRIMARY KEY,
                    sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    content TEXT NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    is_read BOOLEAN NOT NULL DEFAULT FALSE
                );

                -- Indexes for better performance
                CREATE INDEX idx_messages_sender ON messages(sender_id);
                CREATE INDEX idx_messages_recipient ON messages(recipient_id);
                CREATE INDEX idx_messages_created_at ON messages(created_at);

Step 4:
Portforward Auth and WS service 

Auth : kubectl port-forward -n messaging-app service/auth-service 8080:8080
WS : kubectl port-forward -n messaging-app service/ws-service 8081:8081


Now Open Postman and Import Given Postman collection
Find Below APIs and test them
Signup
Login
Validate
refresh

Create 2 users and you should be able to chat among themselves

For WS use below URL
ws://localhost:8081/ws?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTA0MjUxNTgsInVzZXJfaWQiOjJ9.vA91IdcvY7sGZBcZnXDOL0_0D4ryRhMnyT420ZeDWOs

Replace token with your token