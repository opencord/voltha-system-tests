import os
import fileinput
import time
import sys
start_time = time.time()
count = 0
targetOnus = int(sys.argv[1])
for line in fileinput.input():
    if "ONU-activate-indication-received" in line:
        count+=1

    if count == targetOnus:
        break
sys.exit(0)