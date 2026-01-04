# Docker Deployment Guide

This guide explains how to deploy Quenti using Docker and Docker Compose.

## Prerequisites

- Docker 20.10 or higher
- Docker Compose 2.0 or higher
- At least 2GB of available RAM
- Google OAuth credentials (see main README.md for setup instructions)

## Quick Start

1. **Copy the environment file**
   ```bash
   cp .env.docker .env
   ```

2. **Generate required secrets**
   ```bash
   # Generate NEXTAUTH_SECRET
   openssl rand -base64 32
   
   # Generate QUENTI_ENCRYPTION_KEY
   openssl rand -base64 24
   ```

3. **Edit `.env` file**
   - Set `NEXTAUTH_SECRET` with the first generated value
   - Set `QUENTI_ENCRYPTION_KEY` with the second generated value
   - Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` (see [Google OAuth Setup](#google-oauth-setup))
   - Optionally change `POSTGRES_PASSWORD` and other database credentials
   - Update `NEXTAUTH_URL` and `NEXT_PUBLIC_APP_URL` if deploying to a custom domain

4. **Build and start the services**
   ```bash
   docker-compose up -d
   ```

5. **Initialize the database**
   ```bash
   # Wait for the containers to be healthy (about 30-60 seconds)
   docker-compose exec app bun prisma db push
   ```

6. **Access the application**
   
   Open http://localhost:3000 in your browser.

## Google OAuth Setup

You need to configure Google OAuth for authentication:

1. Go to [Google Cloud Console](https://console.developers.google.com/)
2. Create a new project or select an existing one
3. Enable the Google+ API
4. Go to Credentials → Create Credentials → OAuth client ID
5. Choose "Web Application"
6. Add authorized JavaScript origins:
   - `http://localhost:3000` (for local testing)
   - Your production domain (e.g., `https://your-domain.com`)
7. Add authorized redirect URIs:
   - `http://localhost:3000/api/auth/callback/google` (for local)
   - `https://your-domain.com/api/auth/callback/google` (for production)
8. Copy the Client ID and Client Secret to your `.env` file

## Configuration

### Environment Variables

Key environment variables in `.env`:

- `POSTGRES_PASSWORD`: Database password (change for production!)
- `NEXTAUTH_SECRET`: Secret for NextAuth.js session encryption
- `NEXTAUTH_URL`: Full URL where your app is hosted
- `QUENTI_ENCRYPTION_KEY`: Encryption key for sensitive data
- `GOOGLE_CLIENT_ID` & `GOOGLE_CLIENT_SECRET`: Google OAuth credentials
- `APP_PORT`: Port to expose the application (default: 3000)
- `POSTGRES_PORT`: Port to expose PostgreSQL (default: 5432)

### Ports

By default:
- Application: http://localhost:3000
- PostgreSQL: localhost:5432

Change these by setting `APP_PORT` and `POSTGRES_PORT` in your `.env` file.

## Management Commands

### View logs
```bash
# All services
docker-compose logs -f

# Application only
docker-compose logs -f app

# Database only
docker-compose logs -f db
```

### Stop services
```bash
docker-compose down
```

### Stop and remove volumes (⚠️ deletes all data)
```bash
docker-compose down -v
```

### Rebuild application
```bash
docker-compose build app
docker-compose up -d app
```

### Database operations
```bash
# Run Prisma migrations
docker-compose exec app bun prisma migrate deploy

# Open Prisma Studio
docker-compose exec app bun prisma studio

# Database backup
docker-compose exec db pg_dump -U quenti quenti > backup.sql

# Database restore
cat backup.sql | docker-compose exec -T db psql -U quenti quenti
```

### Access application shell
```bash
docker-compose exec app sh
```

### Access database shell
```bash
docker-compose exec db psql -U quenti -d quenti
```

## Production Deployment

For production deployments:

1. **⚠️ CRITICAL: Change all placeholder values**: All values starting with `CHANGE_ME_` in your `.env` file MUST be replaced with actual secure values
2. **Use strong passwords**: Generate secure passwords for `POSTGRES_PASSWORD` and `METRICS_API_PASSWORD`
3. **Use HTTPS**: Set up a reverse proxy (nginx, traefik, etc.) with SSL/TLS
4. **Update URLs**: Set `NEXTAUTH_URL` and `NEXT_PUBLIC_APP_URL` to your production domain
5. **Secure the database**: Don't expose PostgreSQL port publicly (remove port mapping)
6. **Set up backups**: Implement automated database backups
7. **Configure email**: Set up Resend API for email functionality
8. **Monitor resources**: Ensure adequate CPU and memory resources
9. **Use Docker secrets**: Consider using Docker secrets for sensitive data

### Example nginx reverse proxy config

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Troubleshooting

### Application won't start
- Check logs: `docker-compose logs app`
- Verify environment variables are set correctly
- Ensure database is healthy: `docker-compose ps`

### Database connection errors
- Wait for database to be ready (check `docker-compose logs db`)
- Verify `DATABASE_URL` is correct
- Check if database container is running: `docker-compose ps db`

### Build fails
- Ensure you have enough disk space
- Try rebuilding: `docker-compose build --no-cache app`
- Check if all required environment variables are set

### Port already in use
- Change `APP_PORT` or `POSTGRES_PORT` in `.env`
- Or stop the conflicting service

## Architecture

The Docker setup consists of:

1. **Multi-stage Dockerfile**: 
   - `deps`: Installs dependencies
   - `builder`: Builds the application
   - `runner`: Minimal production image

2. **Docker Compose services**:
   - `db`: PostgreSQL 16 database
   - `app`: Quenti Next.js application

3. **Volumes**:
   - `postgres_data`: Persistent database storage

4. **Networks**:
   - `quenti-network`: Bridge network for service communication

## Support

For issues or questions:
- Check the main [README.md](./README.md)
- Visit the [Quenti repository](https://github.com/quenti-io/quenti)
- Open an issue on GitHub
