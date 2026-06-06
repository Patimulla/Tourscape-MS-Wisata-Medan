FROM php:8.2-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libcurl4-openssl-dev \
    libicu-dev \
    libonig-dev \
    libpq-dev \
    && docker-php-ext-install \
        curl \
        intl \
        mbstring \
        pgsql \
        pdo_pgsql \
    && a2enmod rewrite headers \
    && sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf \
    && sed -ri '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

COPY . .

RUN composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction \
    && mkdir -p writable/cache writable/logs writable/session writable/uploads \
    && chown -R www-data:www-data writable \
    && chmod -R 775 writable

COPY docker/start-apache.sh /usr/local/bin/start-apache
RUN chmod +x /usr/local/bin/start-apache

EXPOSE 8080

CMD ["/usr/local/bin/start-apache"]
