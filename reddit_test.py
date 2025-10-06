#!/usr/bin/env python3
"""
End-to-end test script for opening Reddit.com in remote Chrome container.
Documents response with screenshot and logs.
"""

import time
import logging
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_reddit_load():
    """Test loading Reddit.com and document the response."""
    start_time = time.time()

    # Configure Chrome options for remote connection
    chrome_options = Options()
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")

    try:
        # Connect to remote Selenium Chrome
        logger.info("Connecting to remote Chrome at localhost:4444")
        driver = webdriver.Remote(
            command_executor='http://localhost:4444/wd/hub',
            options=chrome_options
        )

        # Navigate to Reddit
        logger.info("Navigating to Reddit.com")
        driver.get("https://www.reddit.com")

        # Wait for page to load (wait for main content)
        WebDriverWait(driver, 30).until(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )

        load_time = time.time() - start_time
        page_title = driver.title

        logger.info(f"Page loaded in {load_time:.2f} seconds")
        logger.info(f"Page title: {page_title}")

        # Take screenshot
        screenshot_path = f"reddit_screenshot_{int(time.time())}.png"
        driver.save_screenshot(screenshot_path)
        logger.info(f"Screenshot saved to: {screenshot_path}")

        # Document response details
        with open(f"reddit_response_{int(time.time())}.log", "w") as f:
            f.write(f"Load Time: {load_time:.2f} seconds\n")
            f.write(f"Page Title: {page_title}\n")
            f.write(f"Current URL: {driver.current_url}\n")
            f.write(f"Screenshot: {screenshot_path}\n")

        logger.info("Test completed successfully")

    except Exception as e:
        logger.error(f"Test failed: {str(e)}")
        raise
    finally:
        if 'driver' in locals():
            driver.quit()

if __name__ == "__main__":
    test_reddit_load()