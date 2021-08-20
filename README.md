# Perl Load Testing and Reports

## About
# we found issues while evaluating client server TPS.

## How to calculate TPS? 
[Calculate TPS](https://www.perfmatrix.com/tps-calculator/)

## How to run and steps? 
1. update payer_id and host_name and token based on env you want to conduct the test.
2. run ```carton install``` 
3. Run file ```carton exec perl load_testing.pl```

## issues
2. If you have issues to run threads in your local then you can use forks instead. Both libs work the same way.
# Author -- Tony Aizize
