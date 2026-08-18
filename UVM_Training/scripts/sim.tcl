database -open -shm dump -compress -incsize 100M -into dump -default

probe -create [scope -tops] \
      -all -variables -memories -functions -tasks \
      -depth all -dynamic -emptyok

# UVM hierarchy / objects
probe -create -database dump $uvm:{uvm_test_top} -all -depth all -dynamic

run 10000000000
exit
