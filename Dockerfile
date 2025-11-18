FROM cirrusci/flutter:latest AS builder

WORKDIR /app

# Copy pubspec files and get dependencies
COPY pubspec.* ./
RUN flutter pub get

# Copy only frontend source files
COPY lib/ lib/
COPY assets/ assets/
COPY web/ web/
COPY analysis_options.yaml ./
COPY pubspec.yaml ./
COPY pubspec.lock ./

RUN flutter build web --release

FROM nginx:stable-alpine

# Replace default nginx config with our SPA-friendly config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built web output
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
