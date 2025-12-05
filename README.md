# Lakukan Drive

Lakukan Drive provides a file managing interface within a specified directory and it can be used to upload, delete, preview and edit your files. It is a **create-your-own-cloud**-kind of software where you can just install it on your server, direct it to a path and access your files through a nice web interface.

## Features

- 📁 **File Management**: Upload, delete, rename, move, and copy files
- 👀 **File Preview**: Preview images, videos, documents, and more
- ✏️ **File Editing**: Edit text files directly in the browser
- 🔍 **Search**: Search through your files and folders
- 👥 **User Management**: Multiple users with different permissions
- 🔗 **File Sharing**: Share files and folders with links
- 🌐 **Multi-language**: Support for multiple languages
- 📱 **Responsive**: Works on desktop and mobile devices


## Project Structure

```
.
├── backend/                    # Go backend application
│   ├── main.go                # Application entry point
│   ├── cmd/                   # Command line interface
│   ├── http/                  # HTTP handlers
│   ├── auth/                  # Authentication
│   ├── users/                 # User management
│   ├── files/                 # File operations
│   └── ...                   # Other backend modules
├── frontend/                   # Vue.js frontend
│   ├── src/                   # Source code
│   ├── public/                # Static assets
│   └── dist/                  # Built frontend
├── docker/                     # Docker configurations
├── www/                        # Documentation
└── README.md                   # This file
```

## Quick Start

### Using Docker

```bash
docker run -d \
  -p 8080:80 \
  -v /path/to/your/files:/srv \
  lakukandrive/lakukandrive:latest
  --d name/lakukan/drive
```

### Building from Source

1. **Build Backend**:
   ```bash
   cd backend
   go build -o lakukandrive .
   ```

2. **Build Frontend**:
   ```bash
   cd frontend
   npm install
   npm run build
   ```

3. **Run the Application**:
   ```bash
   ./backend/lakukandrive
   ```

## Configuration

Lakukan Drive can be configured through:
- Command line flags
- Configuration file (JSON, YAML, or TOML)
- Environment variables

For detailed configuration options, see the documentation.

## Contributing

This is a private project. Contributions are only accepted from authorized team members.

## License

**Private License** © Lakukan Drive Team

This project is proprietary software and may not be copied, modified, or distributed without explicit permission from the copyright holders.

## Support

For support and questions, please contact the Lakukan Drive team through internal channels.
