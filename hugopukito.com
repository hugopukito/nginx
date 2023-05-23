map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}

limit_req_zone $binary_remote_addr zone=limitreqsbyaddr:20m rate=1000r/s;
limit_req_status 429;

server {
  listen 80;
  server_name hugopukito.com www.hugopukito.com;
  return 301 https://$server_name$request_uri;
}

server {  
  listen 443 ssl http2;
  server_name hugopukito.com www.hugopukito.com;

  ssl_certificate /etc/letsencrypt/live/hugopukito.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/hugopukito.com/privkey.pem;

  root /home/pukito/front-vuejs/dist;
  index index.html;
  try_files $uri $uri/ /index.html;
  
  location = / {
    limit_req zone=limitreqsbyaddr;
  }

  location /portfolio {
    root /home/pukito;
    try_files $uri /portfolio/index.html;
  }

  location /cv {
    alias /home/pukito/cv/cv.pdf;
    default_type application.pdf;
  }

  location /cv-english {
    alias /home/pukito/cv/cv-english.pdf;
    default_type application.pdf;
  }

  location /grafana/ {
    proxy_pass http://localhost:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Server $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
  }

  location /grafana/api/live/ {
    rewrite  ^/grafana/(.*)  /$1 break;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $http_host;
    proxy_pass http://localhost:3000/;
    proxy_set_header X-Forwarded-Proto https;
  }

  location /api/ {
    rewrite  ^/api/(.*)  /$1 break;
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    limit_req zone=limitreqsbyaddr;
  }

  location /api/chat {
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Host $http_host;
    proxy_set_header Upgrade websocket;
    proxy_set_header Connection Upgrade;
    proxy_pass http://127.0.0.1:8080/chat;
  }

  location /api/game {
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Host $http_host;
    proxy_set_header Upgrade websocket;
    proxy_set_header Connection Upgrade;
    proxy_pass http://127.0.0.1:8080/game;
  }

  error_page 500 502 503 504 /50x.html;

  location = /50x.html {
    root /usr/share/nginx/html;
  }
}
