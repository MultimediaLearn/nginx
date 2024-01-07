## 编译
```
./build.sh

```

## 启停
```sh
# 启动
./out/sbin/nginx
```

## 升级
```sh
# 通知老master，开始热升级
pkill -F out/logs/nginx.pid -USR2
```


# 测试

### nginx
```sh
# 启动
sudo ./test/bin/nginx -p test/
# 停止
sudo ./test/bin/nginx -p test/ -s stop
```

### FFmpeg
```sh
# 推流
ffmpeg -re -stream_loop -1 -i ~/video/online.ts -c copy -f flv rtmp://localhost:1935/trtc_partner/vacingfang
# 拉流
ffmpeg -i rtmp://localhost:1935/trtc_partner/vacingfang -c copy test.flv -y
```

