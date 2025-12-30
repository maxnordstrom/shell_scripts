# Uppgift 4 - Listor

words = ["failed", "error", "unauthorized"]

output = ""

for word in words:
  output += f"{word}, "

output = output[:-2]

print(output)


# Kan även skriva ut listan utan att använda en loop eller att deklarera en tom variabel så här:
# 
# print(", ".join(words))