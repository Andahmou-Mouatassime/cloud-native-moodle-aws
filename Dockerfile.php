FROM php:8.3-fpm

# 1. Installation des dépendances système
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 2. Installation des extensions PHP pour Moodle
RUN docker-php-ext-install mysqli gd zip intl xml soap opcache
RUN pecl install redis && docker-php-ext-enable redis

# 3. Configuration PHP personnalisée
RUN echo "max_input_vars = 5000" > /usr/local/etc/php/conf.d/moodle-custom.ini

COPY --chown=www-data:www-data ./moodle_code /var/www/html/
RUN mkdir -p /var/www/moodledata \
    && chown -R www-data:www-data /var/www/moodledata \
    && chmod -R 777 /var/www/moodledata