FROM php:8.2-cli

# Install dependencies for SOAP
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    && docker-php-ext-install soap

WORKDIR /app

# Copy API code
COPY index.php /app/

EXPOSE 8080

CMD ["php", "-S", "0.0.0.0:8080", "-t", "/app"]
