import os

def rename_content(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        new_content = content.replace("Audiobookshelf", "Audiobookphile")
        new_content = new_content.replace("audiobookshelf", "audiobookphile")
        
        if new_content != content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated content in {file_path}")
    except Exception as e:
        pass

for root, dirs, files in os.walk("."):
    if ".git" in root or ".build" in root or "build" in root.split(os.sep):
        continue
    for file in files:
        if file.endswith((".swift", ".pbxproj", ".xcconfig", ".xcstrings", ".txt", ".xcscheme", ".xcworkspacedata", ".md", ".swift", ".yml")) or file == "Package.swift" or file == "Skip.env":
            rename_content(os.path.join(root, file))

