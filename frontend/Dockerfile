# Development stage
FROM node:24-alpine AS development

WORKDIR /app

# Install pnpm globally
RUN npm install -g pnpm@10.24.0

# Copy package files first for better caching
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy all frontend files
COPY . .

# Expose port for development server
EXPOSE 5173

# Start development server with pnpm dev
CMD ["pnpm", "dev", "--host", "0.0.0.0"]