import tkinter as tk
from tkinter import messagebox, ttk
import requests
import json
import base64
import datetime

# --- CONFIGURATION (GitHub အချက်အလက်များ ထည့်ရန်) ---
GITHUB_TOKEN = "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" # သင့် GitHub Token
REPO_PATH = "mratommr619-ui/titan-db"        # ဥပမာ - "koko/my-database"
FILE_NAME = "users.json"

class TitanAdmin:
    def __init__(self, root):
        self.root = root
        self.root.title("TITAN AI - Admin License Manager")
        self.root.geometry("500x450")
        self.root.configure(bg="#1c1c1c")

        # Style Settings
        style = ttk.Style()
        style.theme_use('clam')

        # UI Components
        tk.Label(root, text="TITAN AI LICENSE CONTROL", font=("Arial", 16, "bold"), fg="cyan", bg="#1c1c1c").pack(pady=20)

        # Device UID Input
        tk.Label(root, text="User Device UID:", fg="white", bg="#1c1c1c").pack(anchor="w", padx=50)
        self.entry_uid = tk.Entry(root, width=40, font=("Consolas", 10))
        self.entry_uid.pack(pady=5)

        # Days to Add Input
        tk.Label(root, text="Add Days (e.g., 30 for 1 month):", fg="white", bg="#1c1c1c").pack(anchor="w", padx=50)
        self.entry_days = tk.Entry(root, width=15, font=("Arial", 10))
        self.entry_days.insert(0, "30")
        self.entry_days.pack(pady=5)

        # Action Button
        self.btn_update = tk.Button(root, text="UPDATE / ACTIVATE ACCESS", command=self.process_update, 
                                   bg="cyan", fg="black", font=("Arial", 10, "bold"), padx=20, pady=10)
        self.btn_update.pack(pady=30)

        # Status Display
        self.status_text = tk.Text(root, height=8, width=50, bg="#2d2d2d", fg="lightgreen", font=("Consolas", 9))
        self.status_text.pack(pady=10)

    def log(self, message):
        self.status_text.insert(tk.END, f"> {message}\n")
        self.status_text.see(tk.END)

    def get_github_data(self):
        url = f"https://api.github.com/repos/{REPO_PATH}/contents/{FILE_NAME}"
        headers = {"Authorization": f"token {GITHUB_TOKEN}"}
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"GitHub Error: {response.status_code}")

    def process_update(self):
        uid = self.entry_uid.get().strip()
        try:
            days = int(self.entry_days.get())
        except:
            messagebox.showerror("Error", "Days နေရာတွင် ဂဏန်းသာရိုက်ပါ")
            return

        if not uid:
            messagebox.showerror("Error", "Device UID ထည့်ပါ")
            return

        self.log("Connecting to GitHub...")
        try:
            # 1. Fetch current database
            file_data = self.get_github_data()
            sha = file_data['sha']
            content = base64.b64decode(file_data['content']).decode('utf-8')
            db = json.loads(content)
            
            users = db.get("users", {})

            # 2. Logic: Existing or New User
            if uid in users:
                username = users[uid]['username']
                # လက်ရှိ Expiry ကို စစ်မယ်၊ ကုန်နေရင် ဒီနေ့ကစပေါင်းမယ်၊ မကုန်သေးရင် ရှိတာပေါ်ထပ်ပေါင်းမယ်
                current_expiry = datetime.datetime.fromisoformat(users[uid]['expiry'])
                base_date = max(current_expiry, datetime.datetime.now())
                new_expiry = base_date + datetime.timedelta(days=days)
                
                users[uid]['expiry'] = new_expiry.isoformat()
                action_msg = f"Extended {username}"
            else:
                # User အသစ်အတွက် Username ထုတ်ပေးခြင်း (UA -> UB logic)
                prefix = db.get("current_prefix", "UA")
                last_no = db.get("last_no", 0) + 1
                
                if last_no > 999999:
                    # UA -> UB ပြောင်းလဲခြင်း
                    last_char = prefix[1]
                    next_char = chr(ord(last_char) + 1)
                    prefix = f"U{next_char}"
                    last_no = 1
                
                username = f"{prefix}{str(last_no).zfill(6)}"
                new_expiry = datetime.datetime.now() + datetime.timedelta(days=days)
                
                users[uid] = {
                    "username": username,
                    "expiry": new_expiry.isoformat()
                }
                db["last_no"] = last_no
                db["current_prefix"] = prefix
                action_msg = f"Registered {username}"

            # 3. Push back to GitHub
            db["users"] = users
            updated_content = base64.b64encode(json.dumps(db, indent=4).encode('utf-8')).decode('utf-8')
            
            put_url = f"https://api.github.com/repos/{REPO_PATH}/contents/{FILE_NAME}"
            put_headers = {"Authorization": f"token {GITHUB_TOKEN}"}
            put_data = {
                "message": f"Admin: {action_msg}",
                "content": updated_content,
                "sha": sha
            }
            
            put_res = requests.put(put_url, headers=put_headers, json=put_data)
            
            if put_res.status_code == 200:
                self.log(f"SUCCESS: {action_msg}")
                self.log(f"New Expiry: {new_expiry.date()}")
                messagebox.showinfo("Success", f"{username} အား ရက်ပေါင်း {days} တိုးပေးပြီးပါပြီ။")
            else:
                self.log(f"Failed to update GitHub: {put_res.status_code}")

        except Exception as e:
            self.log(f"ERROR: {str(e)}")
            messagebox.showerror("Error", str(e))

if __name__ == "__main__":
    root = tk.Tk()
    app = TitanAdmin(root)
    root.mainloop()