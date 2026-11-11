import os

nes_test_log = open("nestest.log")
my_log = open("mylog.log")

passed = 0

for my, test in zip(my_log, nes_test_log):
    a = "".join(my.split())
    b = "".join(test.split())
    
    if a == b:
       passed += 1
    else:
        print(f"Expected -> {test}", end="")
        print(f"Found    -> {my}", end="")
        break
 
print(f"Passed: {passed}")
