set -e

echo "=== [1/6] Cài đặt Nginx và các công cụ cần thiết ==="
apt-get update -y
apt-get install -y nginx curl python3 ufw

# Mở cổng 80 và 22 trên tường lửa UFW (nếu UFW đang kích hoạt)
if ufw status | grep -q "Status: active"; then
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw reload
fi

echo "=== [2/6] Tạo thư mục web tĩnh và tệp index.html ==="
mkdir -p /var/www/html

cat << 'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bài 4: Reverse Proxy Nginx & Spring Boot</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            color: #f8fafc;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 24px;
        }
        .card {
            background: rgba(30, 41, 59, 0.85);
            border: 1px solid rgba(255, 255, 255, 0.12);
            backdrop-filter: blur(16px);
            border-radius: 20px;
            padding: 40px;
            max-width: 650px;
            width: 100%;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
            text-align: center;
        }
        .badge {
            display: inline-block;
            background: #0284c7;
            color: #ffffff;
            padding: 6px 16px;
            border-radius: 9999px;
            font-size: 0.85rem;
            font-weight: 600;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            margin-bottom: 20px;
        }
        h1 { color: #38bdf8; font-size: 1.85rem; margin-bottom: 12px; font-weight: 700; }
        .subtitle { color: #94a3b8; font-size: 1.05rem; margin-bottom: 28px; line-height: 1.5; }
        .info-card {
            background: #0f172a;
            border-radius: 12px;
            padding: 20px;
            text-align: left;
            margin-bottom: 24px;
            border-left: 4px solid #38bdf8;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.06);
            font-size: 0.95rem;
        }
        .info-row:last-child { border-bottom: none; }
        .info-label { color: #94a3b8; font-weight: 500; }
        .info-value { color: #f1f5f9; font-weight: 600; font-family: monospace; }
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: rgba(16, 185, 129, 0.2);
            color: #34d399;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 0.85rem;
            font-weight: 600;
        }
        .status-dot {
            width: 8px;
            height: 8px;
            background: #10b981;
            border-radius: 50%;
            display: inline-block;
        }
        .routes-section {
            background: #1e293b;
            border-radius: 12px;
            padding: 18px;
            text-align: left;
            margin-top: 20px;
            font-size: 0.9rem;
        }
        .routes-title { color: #e2e8f0; font-weight: 600; margin-bottom: 10px; font-size: 0.95rem; }
        .route-item { margin: 6px 0; color: #cbd5e1; }
        .route-tag {
            background: #334155;
            color: #a5f3fc;
            padding: 2px 8px;
            border-radius: 4px;
            font-family: monospace;
            font-size: 0.85rem;
        }
        footer { margin-top: 24px; font-size: 0.85rem; color: #64748b; }
    </style>
</head>
<body>
    <div class="card">
        <span class="badge">Session 07 — Bài tập 4</span>
        <h1>Cấu hình Reverse Proxy Nginx cho Spring Boot</h1>
        <p class="subtitle">Định tuyến lưu lượng tĩnh (Static Web) và chuyển tiếp API Backend</p>

        <div class="info-card">
            <div class="info-row">
                <span class="info-label">Họ và tên học viên:</span>
                <span class="info-value">Nguyễn Mạnh Hùng</span>
            </div>
            <div class="info-row">
                <span class="info-label">Mã lớp:</span>
                <span class="info-value">DevOps_01</span>
            </div>
            <div class="info-row">
                <span class="info-label">Trạng thái Nginx:</span>
                <span class="status-badge"><span class="status-dot"></span> 200 OK (Static Serve)</span>
            </div>
            <div class="info-row">
                <span class="info-label">Thư mục tĩnh:</span>
                <span class="info-value">/var/www/html/</span>
            </div>
        </div>

        <div class="routes-section">
            <div class="routes-title">Quy tắc định tuyến Nginx Path Matching:</div>
            <div class="route-item">
                <span class="route-tag">GET /</span> &rarr; Phục vụ trực tiếp từ <code>/var/www/html/index.html</code>
            </div>
            <div class="route-item">
                <span class="route-tag">GET /api/*</span> &rarr; Reverse Proxy chuyển tiếp tới <code>http://127.0.0.1:8082/</code>
            </div>
        </div>

        <footer>
            Hệ thống triển khai trên Ubuntu 22.04 LTS &bull; Nginx Reverse Proxy
        </footer>
    </div>
</body>
</html>
EOF

echo "=== [3/6] Tạo tệp cấu hình Virtual Host /etc/nginx/sites-available/spring-proxy.conf ==="
cat << 'EOF' > /etc/nginx/sites-available/spring-proxy.conf
# /etc/nginx/sites-available/spring-proxy.conf
# Cấu hình Reverse Proxy Nginx cho ứng dụng Spring Boot

server {
    listen 80;
    server_name localhost _;

    # 1. Đường dẫn / (Static Serve): Trỏ vào thư mục /var/www/html/
    location / {
        root /var/www/html;
        index index.html index.htm;
        try_files $uri $uri/ =404;
    }

    # 2. Đường dẫn /api/ (Reverse Proxy): Chuyển tiếp (proxy_pass) đến Spring Boot (port 8082)
    location /api/ {
        proxy_pass http://127.0.0.1:8082/;

        # Cấu hình tiêu đề HTTP chuyển tiếp trong khối proxy để Backend nhận diện đúng Client
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Tối ưu hóa Reverse Proxy
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
EOF

echo "=== [4/6] Kích hoạt cấu hình (symlink) và hủy trang default ==="
ln -sf /etc/nginx/sites-available/spring-proxy.conf /etc/nginx/sites-enabled/spring-proxy.conf
rm -f /etc/nginx/sites-enabled/default

echo "=== [5/6] Đảm bảo Backend Spring Boot chạy tại cổng 8082 ==="
# Kiểm tra nếu cổng 8082 chưa có tiến trình nào lắng nghe, khởi tạo Spring Boot mock service
if ss -tulpn | grep -q ":8082 "; then
    echo "=> Cổng 8082 đã có tiến trình Backend đang hoạt động."
else
    echo "=> Cổng 8082 chưa chạy. Khởi tạo dịch vụ Backend mô phỏng Spring Boot..."
    mkdir -p /opt/springboot-mock
    cat << 'EOF' > /opt/springboot-mock/server.py
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class SpringBootHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('X-Application', 'Spring-Boot-Backend')
        self.end_headers()

        response = {
            "status": "UP",
            "application": "Spring Boot Service (Simulated Backend)",
            "port": 8082,
            "path": self.path,
            "client_ip": self.headers.get('X-Real-IP', self.client_address[0]),
            "host": self.headers.get('Host', '')
        }
        self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

    def log_message(self, format, *args):
        # Tắt bớt log stdout mặc định
        return

if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 8082), SpringBootHandler)
    server.serve_forever()
EOF

    cat << 'EOF' > /etc/systemd/system/springboot-backend.service
[Unit]
Description=Spring Boot Backend Service on Port 8082
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /opt/springboot-mock/server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable springboot-backend.service
    systemctl restart springboot-backend.service
    echo "=> Backend Spring Boot đã được khởi động trên http://127.0.0.1:8082/"
fi

echo "=== [6/6] Kiểm tra cú pháp Nginx và Khởi động lại dịch vụ ==="
nginx -t
systemctl restart nginx
systemctl enable nginx

echo ""
echo "=================================================================="
echo "    KẾT QUẢ KIỂM TRA DỊCH VỤ (VERIFICATION TESTS)"
echo "=================================================================="
echo ""
echo "[Test 1] Kiểm tra Header trang tĩnh: curl -I http://localhost/"
curl -I http://localhost/

echo ""
echo "[Test 2] Kiểm tra Nội dung trang tĩnh (trích đoạn HTML): curl http://localhost/ | grep -E 'Họ và tên|Mã lớp'"
curl -s http://localhost/ | grep -E 'Họ và tên|Mã lớp' || true

echo ""
echo "[Test 3] Kiểm tra Header API Reverse Proxy: curl -I http://localhost/api/health"
curl -I http://localhost/api/health

echo ""
echo "[Test 4] Kiểm tra Nội dung API Reverse Proxy: curl http://localhost/api/health"
curl -s http://localhost/api/health

echo ""
echo "=================================================================="
echo "  HOÀN THÀNH CẤU HÌNH BÀI 4 THÀNH CÔNG!"
echo "=================================================================="
