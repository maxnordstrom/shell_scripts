# UPPGIFT 7 - FILHANTERING

with open("sample.log", "r") as f:
  for line in f:
    print(line.strip())


# Man kan även lösa det så här:
#
# sample = "sample.log"
#
# with open(sample, "r") as f:
#   for line in f:
#     print(line.strip())
