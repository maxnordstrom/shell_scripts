# Uppgift 3

username = input("Enter username: ")
username = username.lower()

if username == "admin":
  print("Admin logged in.")
else:
  print("Normal user logged in.")


# För att få lowercase hade man även kunnat göra så här:
# 
# username = input("Enter username: ").lower()
#
# ELLER i if-satsen
#
# if name.lower() == "admin":