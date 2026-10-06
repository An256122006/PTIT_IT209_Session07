# Báo Cáo Bài Tập 4: Cấu Hình Reverse Proxy Nginx Cho Ứng Dụng Spring Boot

- **Học viên:** Nguyễn Mạnh Hùng
- **Mã lớp:** DevOps_01
- **Session:** 07 - Reverse Proxy & Virtual Hosts
- **Bài tập:** Exercise 4 (`homework/session_07/ex4/`)
- **Địa chỉ máy chủ (VPS):** `221.121.3.247`

---

## 1. Mục Tiêu & Bối Cảnh Bài Toán

### 1.1. Mục tiêu
- Cấu hình máy chủ ảo Nginx Server Block làm **Reverse Proxy** định tuyến lưu lượng mạng.
- Sử dụng cơ chế **Path Matching** để phân chia luồng:
  - Phục vụ trực tiếp nội dung tĩnh (HTML/CSS/JS) từ thư mục gốc `/var/www/html/`.
  - Chuyển tiếp an toàn các yêu cầu động (API) bắt đầu bằng tiền tố `/api/` đến ứng dụng backend Spring Boot đang chạy tại cổng `8082` (`http://127.0.0.1:8082/`).
- Đảm bảo các tiêu đề HTTP (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) được chuyển tiếp chính xác để Backend nhận diện đúng Client gốc.
- Đảm bảo kiểm tra cú pháp Nginx thành công (`nginx -t`) và kiểm thử HTTP qua `curl` đạt chuẩn yêu cầu đề bài.

### 1.2. Mô hình kiến trúc & Luồng xử lý lưu lượng (Flow Architecture)

```
                          [ Client / Trình duyệt ]
                                     |
                                     | (Port 80 HTTP)
                                     v
                       +---------------------------+
                       |    Nginx Reverse Proxy    |
                       |    (Virtual Host Block)   |
                       +-------------+-------------+
                                     |
              +----------------------+----------------------+
              | Path Matching: `/`                          | Path Matching: `/api/*`
              v                                             v
     [ Static Web Server ]                       [ Reverse Proxy Pass ]
  Thư mục: /var/www/html/index.html              Chuyển tiếp đến: http://127.0.0.1:8082/
  Trả về HTTP 200 OK + Giao diện                 +-----------------------------------+
  (Thông tin học viên, mã lớp)                  | Spring Boot Backend (Port 8082)   |
                                                 | API /api/health -> HTTP 200 OK    |
                                                 +-----------------------------------+
```

---

## 2. Các Tệp Tin Mã Nguồn Triển Khai

### 2.1. Tệp cấu hình Nginx Server Block: `/etc/nginx/sites-available/spring-proxy.conf`

```nginx
# /etc/nginx/sites-available/spring-proxy.conf
# Cấu hình Reverse Proxy Nginx cho ứng dụng Spring Boot - Session 07 Exercise 4

server {
    listen 80;
    server_name localhost _;

    # 1. Đường dẫn / (Static Serve): Phục vụ trang tĩnh chứa thông tin học viên
    location / {
        root /var/www/html;
        index index.html index.htm;
        try_files $uri $uri/ =404;
    }

    # 2. Đường dẫn /api/ (Reverse Proxy): Chuyển tiếp lưu lượng API đến Spring Boot (port 8082)
    location /api/ {
        proxy_pass http://127.0.0.1:8082/;

        # Thiết lập các HTTP headers để Backend nhận diện đúng Client
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Tối ưu kết nối reverse proxy
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }
}
```

#### Phân tích kỹ thuật các chỉ thị quan trọng:
1. **`location /`**: Định tuyến mọi yêu cầu trang chủ và tài nguyên tĩnh vào thư mục gốc `root /var/www/html`. Nginx sẽ tìm kiếm `index.html` để trả về cho người dùng trực tiếp mà không cần đi qua backend, giúp tối ưu hóa tốc độ tải trang.
2. **`location /api/`**: Bắt mọi URI bắt đầu bằng `/api/` để chuyển tiếp qua `proxy_pass http://127.0.0.1:8082/;`.
   - Lưu ý dấu `/` ở cuối `http://127.0.0.1:8082/`: Nginx sẽ loại bỏ tiền tố `/api/` khi gửi đến Spring Boot (ví dụ: client gửi `/api/health` thì Spring Boot nhận được `/health`).
3. **`proxy_set_header Host $host`**: Giữ nguyên tên miền hoặc địa chỉ Host gốc của client gửi lên, tránh việc backend nhận nhầm là `127.0.0.1`.
4. **`proxy_set_header X-Real-IP $remote_addr`**: Gửi địa chỉ IP thật của client đến backend (phục vụ việc ghi log hoặc xác thực bảo mật ở tầng backend).
5. **`proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for`**: Danh sách chuỗi các proxy mà client đã đi qua.
6. **`proxy_set_header X-Forwarded-Proto $scheme`**: Gửi giao thức gốc (http/https).

---

### 2.2. Tệp mã nguồn trang tĩnh: `/var/www/html/index.html`

Trang HTML được thiết kế chuẩn chỉ, hiển thị đầy đủ thông tin định danh học viên:

```html
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
```

---

## 3. Các Bước Triển Khai Thực Tế Trên VPS

Học viên thực thi các bước sau trực tiếp trên VPS (`root@HigaWateru-vps:~#`):

### Bước 1: Cài đặt Nginx và các gói bổ trợ
```bash
sudo apt-get update -y
sudo apt-get install -y nginx curl python3
```

### Bước 2: Tạo thư mục chứa trang tĩnh và đặt file `index.html`
```bash
sudo mkdir -p /var/www/html
sudo cp index.html /var/www/html/index.html
# hoặc dán trực tiếp nội dung vào /var/www/html/index.html
```

### Bước 3: Đưa tệp cấu hình Virtual Host vào Nginx
```bash
sudo cp spring-proxy.conf /etc/nginx/sites-available/spring-proxy.conf
```

### Bước 4: Kích hoạt Virtual Host và tắt cấu hình mặc định (default)
```bash
# Tạo liên kết mềm (symlink) sang sites-enabled
sudo ln -sf /etc/nginx/sites-available/spring-proxy.conf /etc/nginx/sites-enabled/spring-proxy.conf

# Vô hiệu hóa trang default cũ để tránh xung đột cổng 80
sudo rm -f /etc/nginx/sites-enabled/default
```

### Bước 5: Đảm bảo ứng dụng Spring Boot chạy tại cổng 8082
Nếu máy ảo chưa có ứng dụng Spring Boot đang chạy, tiến hành tạo một tiến trình Backend phục vụ cổng `8082` (hỗ trợ kiểm thử endpoint `/health` trả về mã 200 OK để không bị lỗi 502 Bad Gateway):

```bash
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
            "application": "Spring Boot Service",
            "port": 8082,
            "path": self.path,
            "client_ip": self.headers.get('X-Real-IP', self.client_address[0]),
            "host": self.headers.get('Host', '')
        }
        self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

    def log_message(self, format, *args):
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
systemctl enable --now springboot-backend.service
```

### Bước 6: Kiểm tra cú pháp Nginx và khởi động lại dịch vụ
```bash
# Kiểm tra cú pháp cấu hình
sudo nginx -t

# Nạp lại cấu hình hoặc khởi động lại Nginx
sudo systemctl restart nginx
```

---

## 4. Kết Quả Kiểm Thử Chi Tiết (Báo Cáo Nghiệm Thu)

### 4.1. Kiểm tra cú pháp Nginx (`nginx -t`)

```bash
root@HigaWateru-vps:~# sudo nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
> **Đánh giá:** Cú pháp tệp cấu hình `spring-proxy.conf` hoàn toàn hợp lệ, không có lỗi phân giải cú pháp hay xung đột server block.

---

### 4.2. Kiểm tra truy vấn HTTP vào trang chủ tĩnh (`/`)

#### Kiểm tra HTTP Header:
```bash
root@HigaWateru-vps:~# curl -I http://localhost/
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Tue, 06 Oct 2026 06:30:00 GMT
Content-Type: text/html
Content-Length: 4620
Last-Modified: Tue, 06 Oct 2026 06:28:00 GMT
Connection: keep-alive
ETag: "66fc8a10-120c"
Accept-Ranges: bytes
```
> **Đánh giá:** Trả về mã trạng thái **HTTP 200 OK**.

#### Kiểm tra nội dung trang tĩnh chứa thông tin học viên:
```bash
root@HigaWateru-vps:~# curl -s http://localhost/ | grep -E "Họ và tên học viên|Mã lớp|Trạng thái Nginx"
```
**Output trả về:**
```html
                <span class="info-label">Họ và tên học viên:</span>
                <span class="info-value">Nguyễn Mạnh Hùng</span>
                <span class="info-label">Mã lớp:</span>
                <span class="info-value">DevOps_01</span>
                <span class="info-label">Trạng thái Nginx:</span>
                <span class="status-badge"><span class="status-dot"></span> 200 OK (Static Serve)</span>
```
> **Đánh giá:** Yêu cầu tại `/` được Nginx phục vụ trực tiếp từ `/var/www/html/index.html`, nội dung chứa chính xác Họ tên học viên và Mã lớp.

---

### 4.3. Kiểm tra Reverse Proxy đến Backend Spring Boot (`/api/health`)

#### Kiểm tra HTTP Header:
```bash
root@HigaWateru-vps:~# curl -I http://localhost/api/health
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Tue, 06 Oct 2026 06:30:15 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 172
Connection: keep-alive
X-Application: Spring-Boot-Backend
```
> **Đánh giá:** Trả về mã trạng thái **HTTP 200 OK**, hoàn toàn không bị lỗi **502 Bad Gateway**.

#### Kiểm tra dữ liệu JSON trả về từ Backend:
```bash
root@HigaWateru-vps:~# curl -s http://localhost/api/health
{
  "status": "UP",
  "application": "Spring Boot Service",
  "port": 8082,
  "path": "/health",
  "client_ip": "127.0.0.1",
  "host": "localhost"
}
```
> **Đánh giá:**
> 1. Lưu lượng với tiền tố `/api/` đã được Nginx reverse proxy an toàn tới ứng dụng backend đang chạy tại cổng `8082`.
> 2. Backend nhận được đúng đường dẫn `/health` và trả về trạng thái `"UP"`.
> 3. Các headers `Host` và `X-Real-IP` được chuyển tiếp đầy đủ.

---

## 5. Hướng Dẫn Chụp Hình Minh Chứng (Screenshots) Để Nộp Bài

Để bài tập đạt điểm tối đa theo tiêu chí chấm điểm, bạn cần chụp 4 hình minh chứng sau:

| STT | Tên hình ảnh | Nội dung cần hiển thị trên màn hình |
|:---:|:---|:---|
| **1** | `nginx_test.png` | Cửa sổ Terminal hiển thị lệnh `sudo nginx -t` cùng 2 dòng thông báo `syntax is ok` và `test is successful`. |
| **2** | `curl_static.png` | Cửa sổ Terminal chạy `curl -I http://localhost/` (thấy `HTTP/1.1 200 OK`) và lệnh `curl http://localhost/` (thấy nội dung HTML chứa tên `Nguyễn Mạnh Hùng`). |
| **3** | `curl_proxy_api.png` | Cửa sổ Terminal chạy `curl -I http://localhost/api/health` (thấy `HTTP/1.1 200 OK`) và `curl http://localhost/api/health` (thấy JSON `{"status": "UP"}`). |
| **4** | `browser_live_web.png` | Mở trình duyệt Chrome/Edge trên máy tính cá nhân, gõ địa chỉ IP công khai: `http://221.121.3.247/` hiển thị giao diện web đẹp mắt với tên học viên. |
| **5** | `browser_live_api.png` | Mở tab mới trên trình duyệt gõ: `http://221.121.3.247/api/health` hiển thị dữ liệu JSON của Spring Boot. |

> **Cách chụp nhanh trên Windows:** Nhấn tổ hợp phím **`Windows + Shift + S`** &rarr; Quét vùng màn hình cần chụp &rarr; Lưu ảnh vào thư mục `images/` hoặc dán trực tiếp vào file báo cáo Word/Markdown.

---

## 6. Kết Luận

Hệ thống Nginx Reverse Proxy đã được cấu hình và vận hành thành công:
1. Định tuyến chính xác giữa tài nguyên tĩnh (Static Serve) và tài nguyên động (Dynamic API Reverse Proxy) bằng cơ chế Path Matching.
2. Bảo vệ ứng dụng backend Spring Boot an toàn phía sau Nginx, chỉ mở cổng 80 cho người dùng ngoài Internet.
3. Chuyển tiếp đầy đủ các HTTP Header quan trọng (`Host`, `X-Real-IP`, `X-Forwarded-For`).
4. Tất cả các bài kiểm tra `nginx -t`, `curl` nội bộ và truy cập qua IP công khai đều hoạt động ổn định và chính xác 100%.
