FROM golang:1.25-alpine AS builder

WORKDIR /app
COPY ./app/go.mod ./app/go.sum ./
RUN go mod download

COPY ./app .
RUN CGO_ENABLED=0 go build -o /app/mutation-webhook .
RUN chmod +x /app/mutation-webhook

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/mutation-webhook /app/mutation-webhook

ENTRYPOINT ["./mutation-webhook"]
