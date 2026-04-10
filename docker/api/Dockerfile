FROM php:8.2-cli

# Install SOAP extension
RUN docker-php-ext-install soap

WORKDIR /app
COPY index.php /app/

EXPOSE 8080

CMD ["php", "-S", "0.0.0.0:8080", "-t", "/app"]
