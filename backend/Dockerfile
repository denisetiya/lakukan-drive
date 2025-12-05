# Backend build stage
FROM golang:1.23-alpine AS builder

# Install git and other necessary build tools
RUN apk add --no-cache git ca-certificates tzdata

# Set the working directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Create empty dist directory to prevent panic (backend only mode)
RUN mkdir -p frontend/dist && echo "Backend only mode - no frontend assets" > frontend/dist/README.txt

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o lakukandrive .

# Add diagnostic logging to verify the binary was created
RUN ls -la /app/lakukandrive && /app/lakukandrive version

# Final stage
FROM alpine:latest

ARG UID=1000
ARG GID=1000

# Install ca-certificates for HTTPS requests and tzdata for timezone support
RUN apk --no-cache add ca-certificates tzdata

# Create a non-root user
RUN addgroup -g ${GID} -S filebrowser && \
    adduser -u ${UID} -S filebrowser -G filebrowser

# Set the working directory
WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/lakukandrive .

# Add diagnostic logging to verify the binary was copied
RUN ls -la /app/lakukandrive

# Change ownership to non-root user
RUN chown -R filebrowser:filebrowser /app

# Switch to non-root user
USER filebrowser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the binary
CMD ["./lakukandrive", "--address", "0.0.0.0"]
