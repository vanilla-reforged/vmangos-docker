FROM php:8.2-cli

RUN apt-get update && apt-get install -y \
    libxml2-dev \
    && docker-php-ext-install soap mysqli \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY index.php /app/

EXPOSE 8090

CMD ["php", "-S", "0.0.0.0:8090", "-t", "/app"]
