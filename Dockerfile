FROM ghcr.io/cirrusci/flutter:stable AS builder

WORKDIR /app

# Copy pubspec first to leverage layer caching
COPY pubspec.* ./
RUN flutter pub get

# Copy the rest and build web
COPY . .
RUN flutter build web --release

FROM nginx:stable-alpine

# Replace default nginx config with our SPA-friendly config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built web output
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
