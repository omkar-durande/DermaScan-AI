import os
import sys
from huggingface_hub import HfApi

def upload():
    if len(sys.argv) < 2:
        print("Usage: python upload_hf.py <YOUR_HF_WRITE_TOKEN>")
        sys.exit(1)
        
    token = sys.argv[1]
    repo_id = "omkardurande/dermascan-api"
    
    files_to_upload = [
        "Dockerfile",
        "main.py",
        "model.py",
        "requirements.txt",
        "skin_model.pth"
    ]
    
    api = HfApi()
    
    print(f"Uploading files to Hugging Face Space: {repo_id}...")
    for file_name in files_to_upload:
        if not os.path.exists(file_name):
            print(f"Error: {file_name} not found in current directory.")
            continue
            
        print(f"Uploading {file_name}...")
        api.upload_file(
            path_or_fileobj=file_name,
            path_in_repo=file_name,
            repo_id=repo_id,
            repo_type="space",
            token=token
        )
        print(f"Successfully uploaded {file_name}")
        
    print("\nAll files uploaded successfully!")

if __name__ == "__main__":
    upload()
