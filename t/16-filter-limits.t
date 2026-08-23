# Copyright (C) 2026 SB Maintainers
# Copyright (C) 2026 Thijs Eilander (myguard-labs)
# Copyright (C) GetPageSpeed LLC
# Copyright (C) Alex Zhang
#
use Test::Nginx::Socket 'no_plan';

no_long_string();
no_shuffle();
run_tests();

__DATA__

=== TEST 1: zstd_max_length skips compression when Content-Length is known and exceeds limit
--- config
    location /filter {
        zstd on;
        zstd_min_length 1;
        zstd_max_length 4;
        zstd_types text/plain;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/big;
    }
    location /big {
        default_type text/plain;
        return 200 "this body is far larger than the 4 byte max_length\n";
    }
--- request
GET /filter
--- more_headers
Accept-Encoding: zstd
--- response_headers
!Content-Encoding
--- no_error_log
[error]



=== TEST 2: zstd_max_length is enforced on a chunked upstream (no Content-Length)
--- config
    location /filter {
        zstd on;
        zstd_min_length 1;
        zstd_max_length 100;
        zstd_types text/plain;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/up;
    }
    location /up {
        proxy_http_version 1.1;
        proxy_pass http://127.0.0.1:$TEST_NGINX_RAND_PORT_1/;
    }
--- tcp_listen: $TEST_NGINX_RAND_PORT_1
--- tcp_no_close
--- tcp_reply eval
"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n"
. sprintf("%x\r\n", 5000) . ("A" x 5000) . "\r\n0\r\n\r\n"
--- request
GET /filter
--- more_headers
Accept-Encoding: zstd
--- ignore_response
--- error_log
input exceeded zstd_max_length (100) on a response with no Content-Length



=== TEST 3: zstd_window_log caps the window and still produces valid output
--- config
    location /filter {
        zstd on;
        zstd_min_length 1;
        zstd_window_log 15;
        zstd_types text/plain;
        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/test;
    }
    location /test {
        default_type text/plain;
        return 200 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n";
    }
--- request
GET /filter
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- no_error_log
[error]



=== TEST 4: zstd_max_cctx_memory rejects parameters that exceed the budget
--- config
    location /filter {
        zstd on;
        zstd_min_length 1;
        zstd_comp_level 19;
        zstd_max_cctx_memory 1k;
        zstd_types text/plain;
        return 200 "x";
    }
--- request
GET /filter
--- must_die



=== TEST 5: $zstd_bytes_in / $zstd_bytes_out are emitted for a compressed response
--- config
    location /filter {
        zstd on;
        zstd_min_length 1;
        zstd_types text/plain;
        set $bin $zstd_bytes_in;
        set $bout $zstd_bytes_out;
        return 200 "testing byte counters in and out\n";
    }
--- request
GET /filter
--- more_headers
Accept-Encoding: zstd
--- response_headers
Content-Encoding: zstd
--- no_error_log
[error]
