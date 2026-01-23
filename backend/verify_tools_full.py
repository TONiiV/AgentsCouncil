"""
End-to-End Verification of Investment Advisor Tools
"""
import asyncio
import os
import logging
from dotenv import load_dotenv
from app.providers.gemini_provider import GeminiProvider
from app.tools import INVESTMENT_TOOLS
from app.models import RoleType

# Load environment variables
load_dotenv()

async def main():
    logging.basicConfig(level=logging.INFO)
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key or api_key.startswith("AIza") is False:
        print(f"GEMINI_API_KEY not found or invalid in .env: {api_key}")
        return

    provider = GeminiProvider(api_key)
    
    system_prompt = """You are an Investment Advisor. 
You have access to stock market tools. 
Use them to suggest whether it is a good time to buy AAPL stock based on current data."""
    
    user_message = "Should I buy AAPL right now? Please check current price and recent news."
    
    print("Sending request to Gemini with tools...")
    try:
        text, tool_calls = await provider.generate_with_tools(
            system_prompt=system_prompt,
            user_message=user_message,
            tools=INVESTMENT_TOOLS
        )
        
        print("\n--- TOOL CALLS MADE ---")
        for tc in tool_calls:
            print(f"Tool: {tc['name']}")
            print(f"Args: {tc['args']}")
            print(f"Result (truncated): {str(tc['result'])[:200]}...")
        
        print("\n--- FINAL RESPONSE ---")
        print(text)
    except Exception as e:
        print(f"Error during verification: {e}")

if __name__ == "__main__":
    asyncio.run(main())
