import sys
from huggingface_hub import HfApi

def main():
    if len(sys.argv) < 2:
        print("Usage: python get_hf_logs.py <YOUR_HF_TOKEN>")
        sys.exit(1)
        
    token = sys.argv[1]
    repo_id = "omkardurande/dermascan-api"
    api = HfApi(token=token)
    
    try:
        print(f"Fetching build logs for {repo_id}...")
        for line in api.fetch_space_logs(repo_id=repo_id, build=True):
            print(line, end="")
    except Exception as e:
        print(f"Error fetching logs: {e}")

if __name__ == "__main__":
    main()
