#!/usr/bin/env python3
from playwright.sync_api import sync_playwright
import sys
import time

def find_requests(url):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()

        found_url = None
        inflight = 0
        last_activity = time.time()

        def on_request(request):
            nonlocal inflight, last_activity, found_url
            inflight += 1
            last_activity = time.time()
            req_url = request.url

            if ".m3u8" in req_url and "MTA4MA" in req_url:
                found_url = req_url
                with open("/tmp/m3u8.txt", "w") as f:
                        f.write(found_url)
                        browser.close()
                        time.sleep(5)
                        sys.exit(0)

        def on_response(response):
            nonlocal inflight, last_activity
            inflight -= 1
            last_activity = time.time()

        # Attach network listeners
        page.on("request", on_request)
        page.on("requestfinished", on_response)
        page.on("requestfailed", on_response)

        print(f"🌐 Navigating to: {url}")
        try:
            page.goto(url)
        except Exception as e:
            print(f"⚠️ Page load failed: {e}")
            browser.close()
            sys.exit(1)

        print("⌛ Waiting for network to become idle...")
        timeout = 15
        idle_time = 2
        start = time.time()

        while True:
            now = time.time()
            if inflight == 0 and now - last_activity >= idle_time:
                break
            if now - start > timeout:
                print("⏱️ Timeout while waiting for network idle.")
                break
            time.sleep(0.1)

        browser.close()

        if found_url:
            print("✅ Done. Matching request captured.")
            sys.exit(0)
        else:
            print("❌ No matching .m3u8 request found.")
            sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python find_m3u8_requests.py <url>")
        sys.exit(1)

    target_url = sys.argv[1]
    find_requests(target_url)

