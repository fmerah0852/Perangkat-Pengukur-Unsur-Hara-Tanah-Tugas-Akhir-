FROM golang:1.22-alpine AS build
WORKDIR /app

COPY go.mod ./
COPY . .

RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o api .

FROM alpine:3.20
WORKDIR /app
COPY --from=build /app/api /app/api
EXPOSE 8080
CMD ["/app/api"]
