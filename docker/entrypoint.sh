#!/bin/sh
set -eu

umask 077

TARGET=/app/config.yaml

# 1) 生成运行配置。优先环境变量注入（适配 Zeabur/K8s 等无法方便挂载文件的平台），
#    否则回退到挂载的配置文件（保持与原行为兼容）。
if [ -n "${GROK2API_CONFIG_BASE64:-}" ]; then
  echo "${GROK2API_CONFIG_BASE64}" | base64 -d > "${TARGET}"
elif [ -n "${GROK2API_CONFIG_CONTENT:-}" ]; then
  printf '%s' "${GROK2API_CONFIG_CONTENT}" > "${TARGET}"
elif [ -f "${GROK2API_CONFIG_SOURCE}" ]; then
  cp "${GROK2API_CONFIG_SOURCE}" "${TARGET}"
else
  echo "missing config: provide GROK2API_CONFIG_BASE64 / GROK2API_CONFIG_CONTENT," >&2
  echo "or mount config.yaml to ${GROK2API_CONFIG_SOURCE}" >&2
  exit 1
fi

# 2) 权限收敛。仅在以 root 运行时才修正属主并降权；平台若已强制以非 root
#    运行（runAsNonRoot / 只读 rootfs），跳过 chown 以免 set -e 触发崩溃循环。
if [ "$(id -u)" = "0" ]; then
  chown grok2api:grok2api "${TARGET}" 2>/dev/null || true
  chmod 0600 "${TARGET}" 2>/dev/null || true
  exec su-exec grok2api:grok2api "$@"
fi

chmod 0600 "${TARGET}" 2>/dev/null || true
exec "$@"
