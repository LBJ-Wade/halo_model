#!/bin/bash

#libs+=('precision')
#libs+=('constants')
libs+=('fix_polynomial')
libs+=('table_integer')
libs+=('array_operations')
#libs+=('ODE_solvers')
libs+=('file_info')
libs+=('interpolate')
libs+=('logical_operations')
libs+=('random_numbers')
libs+=('solve_equations')
#libs+=('sorting')
libs+=('special_functions')
#libs+=('statistics')
libs+=('string_operations')
#libs+=('vectors')
#libs+=('numerology')
libs+=('calculus')
libs+=('calculus_table')
#libs+=('fitting')
#libs+=('fft')
#libs+=('gadget')
#libs+=('field_operations')
#libs+=('cosmology')

libdir='/Users/Mead/Physics/library'

for i in "${libs[@]}"; do
    echo 'Copying:' $i
    cp $libdir/$i/$i.f90 .
done
