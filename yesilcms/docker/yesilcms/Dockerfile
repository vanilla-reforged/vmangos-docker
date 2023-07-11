FROM composer AS composer

# copying the source directory and install the dependencies with composer
COPY <your_directory>/ /app

# run composer install to install the dependencies
RUN composer install \
  --optimize-autoloader \
  --no-interaction \
  --no-progress

# continue stage build with the desired image and copy the source including the
# dependencies downloaded by composer
FROM trafex/php-nginx
COPY --chown=nginx --from=composer /app /var/www/html
