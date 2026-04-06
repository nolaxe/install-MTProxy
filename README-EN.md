[EN](https://github.com/nolaxe/install-MTProxy/blob/main/README-EN.md)  |  [RU](https://github.com/nolaxe/install-MTProxy/blob/main/README.md)    
<img width="37" height="37" alt="image" src="https://github.com/user-attachments/assets/a25adede-03fd-45a9-a07a-befe34a65021" />   |  TLDR: VPS + script below = Telegram acceleration
:--- | :---

## 🚀 Automatic TeleMT Proxy Installation (TG's MTProto protocol) from a ~5MB pre-built image
**Goal:** Speed up Telegram (loading photos and videos)  
**Method:** A proxy server that masks TG traffic as regular web traffic

#### 🛠 Installation  
Run the container setup script:
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-image.sh")
```
...  advanced option (multi-users, ad_tag, viewing usage statistics)
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-image-mu.sh")
```
#### 📋 What the script does:
* Checks for necessary dependencies and installs them if missing (Ubuntu 24)
* Prompts the user for parameters (port, TLS domain)
* Generates secrets (Prefix + Main Key + Domain in HEX)
* Generates `telemt.toml` and `docker-compose.yml` files
* Downloads the pre-built TeleMT image (Source: `https://hub.docker.com/r/whn0thacked/telemt-docker`)
* Starts the installation
* Displays and saves connection links to a file
* Includes an additional script to enable/disable the proxy

#### 📋 What the script DOES NOT do yet:
* `ad_tag` for sponsor channels ⏳
* Multi-user support ⏳

#### 🛠 Installation Process:
`Menu`  
<img width="507" height="294" alt="image" src="https://github.com/user-attachments/assets/a701fd4b-6df0-4ae9-85a5-6d5e81949837" />

`Preparing dependencies`  
<img width="753" height="156" alt="image" src="https://github.com/user-attachments/assets/0d5613ac-8023-44be-a9c0-f9ac35e855e0" />

`Deployment`  
<img width="753" height="263" alt="image" src="https://github.com/user-attachments/assets/b2071e4e-7a4d-4f2d-8549-5e84f31c578c" />

`Result`  
<img width="753" height="94" alt="image" src="https://github.com/user-attachments/assets/b7273739-4a5d-4ab4-b2ca-f2fcac0255f7" />

#### 📦 TeleMT Image Features
* Minimal size.
* Security: `distroless` build.
* Runs as a non-root user.

---
**Option 2** ### Manual Image Build and Server Deployment
Skips dependency checks/installation; requires more than 0.5GB of server RAM for building.
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-source.sh")
```
#### 🛠 Installation Process:
<img width="736" height="232" alt="image" src="https://github.com/user-attachments/assets/096fcb3b-cb7a-4201-8315-2fcc791de821" />

---

<details>
   <summary>Step-by-Step Instructions and Additional Details</summary>
  
> **Description**

TeleMT doesn't just mask traffic; it correctly responds to external attempts to probe your server. If someone connects without the specific secret, TeleMT won't drop the connection; instead, it transparently redirects them to a real website (e.g., amazon.com or any other you specify).

| | Regular Connection | Via MTProto Proxy |
| :--- | :--- | :--- |
| **Concept** | Direct connection to Telegram servers. | Connection via an intermediate server (proxy). |
| **ISP Visibility** | Clearly sees traffic going to Telegram IPs. Can apply DPI and throttle it. | Sees traffic to the proxy IP. Traffic is masked as regular HTTPS (e.g., like Amazon). |
| **Speed under Throttling** | Drops significantly as the ISP intentionally limits this traffic type. | Stays high because the ISP cannot identify it as Telegram traffic. |
| **Purpose** | Standard mode for countries without restrictions. | Bypassing ISP-level throttling. |

> **Instructions**

0) Purchase a VDS (99% of plans include a static IP) outside the restricted zone. Get your login/IP/password.
1) Download PuTTY, for example, here: https://portableapps.com/apps/internet/putty_portable
2) Connect to the server via PuTTY using the credentials from step 0.  
   *(Or create a shortcut with properties: `..\putty_portable.exe root@YOUR_IP_HERE -pw your_pass_here` to avoid re-entering credentials).*
3) Paste the following line into the terminal:
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-image.sh")
```
(Copy the text, then right-click in the terminal to paste and press Enter).  
<img width="519" height="213" alt="image" src="https://github.com/user-attachments/assets/8e825430-5714-460e-8595-7a82cc9b5633" />  

4) Once finished, the script will provide a link like:  
🔗 LINK: `tg://proxy?server=IP&port=PORT&secret=SECRET`
5) **Activation:** Simply copy the link and send it to yourself on Telegram (e.g., to "Saved Messages"), then click it to activate the proxy.  
<img width="371" height="540" alt="image" src="https://github.com/user-attachments/assets/45911a5b-b045-4fc8-8772-df2eef4cfbd2" />
</details>

<details>
   <summary>How to set up a custom domain name</summary>  
To display a domain name instead of an IP address in your link, link your server to a domain via DNS records using free services like:  
https://ydns.io/hosts, https://www.noip.com, https://www.duckdns.org, etc.  
- Resulting in: `tg://proxy?server=rknonelove.ydns.com&port=43&secret=ee667....`  
- Instead of: `tg://proxy?server=157.257.147.157&port=43&secret=ee667c4....`
</details>  

----

#### 🔗 Useful Links  
* TeleMT image build by An0nX: [GitHub](https://github.com/An0nX/telemt-docker) / [Docker Hub](https://hub.docker.com/r/whn0thacked/telemt-docker).
* TeleMT Developers: https://github.com/telemt/telemt

