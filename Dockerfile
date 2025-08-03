FROM redis:7-alpine

# Copy custom Redis configurations
COPY redis-configs/redis.conf /usr/local/etc/redis/redis.conf

# Create data directory
RUN mkdir -p /data && \
    chown redis:redis /data

# Expose Redis port
EXPOSE 6379

# Run Redis with custom configuration
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]