#!/bin/bash   
rm fhem-grohe-ondus.txt
find ./FHEM -type f \( ! -iname ".*" \) -print0 | while IFS= read -r -d '' f; 
  do
   echo "DEL ${f}" >> fhem-grohe-ondus.txt
   out="UPD "$(stat -f "%Sm" -t "%Y-%m-%d_%T" $f)" "$(stat -f%z $f)" ${f}"
   echo ${out//.\//} >> fhem-grohe-ondus.txt
done

# CHANGED file
echo "FHEM Grohe Ondus last changes:" > CHANGED
echo $(date +"%Y-%m-%d") >> CHANGED
echo " - $(git log -1 --pretty=%B)" >> CHANGED
