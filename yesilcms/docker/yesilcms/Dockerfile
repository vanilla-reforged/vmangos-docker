FROM khromov/alpine-nginx-php8

RUN chown -R nobody:nogroup /var/www/html
RUN chmod -R 777 /var/www/html

WORKDIR /var/www/html

CMD composer update
