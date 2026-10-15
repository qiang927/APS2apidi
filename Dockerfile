FROM golang:1.26-alpine AS builder

WORKDIR /build

COPY go.mod go.sum* ./

RUN go mod download

COPY cmd/ ./cmd/
COPY internal/ ./internal/

RUN CGO_ENABLED=0 go build -buildvcs=false -trimpath -ldflags="-s -w" -o vproxy ./cmd/vproxy \
    && go clean -cache -modcache -testcache

FROM alpine:3.20

# jq：入口脚本用它把 Render 分配的 PORT / 管理员密码写进 config.json
RUN apk add --no-cache ca-certificates tzdata bash jq

WORKDIR /app

COPY --from=builder /build/vproxy /app/vproxy
COPY config/config.example.json /app/config.example.json
COPY config/api_keys.example.txt /app/api_keys.example.txt
COPY config/models.json /app/models.json
# 规则文本：入口脚本据此计算"规则版本哈希"，用于 Docker 模式下自动同意
COPY cmd/vproxy/rules.txt /app/rules.txt
COPY entrypoint.sh /app/entrypoint.sh
# 去掉可能被 Windows 编辑器带入的 CRLF，再赋予执行权限
RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh

ENV VPROXY_CONFIG=/app/config/config.json
ENV VPROXY_API_KEYS=/app/config/api_keys.txt
ENV VPROXY_MODELS=/app/config/models.json
# Render 默认端口 10000；入口脚本会把它写进 config.json 的 port_api
ENV PORT=10000

EXPOSE 10000

CMD ["/app/entrypoint.sh"]
