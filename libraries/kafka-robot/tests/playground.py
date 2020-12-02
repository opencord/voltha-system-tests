from datetime import datetime

# ts = int('1606741215546')
ts = datetime.now().timestamp()
print(ts)
ts = int('1606831346403')
ts = datetime.fromtimestamp(int(ts) / 1e3).strftime('%Y-%m-%d %H:%M:%S.%f')
print(type(ts), ts)
