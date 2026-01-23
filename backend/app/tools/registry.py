"""
AgentsCouncil Backend - Tool Registry

Defines tools available to agents and their schemas for function calling.
"""
from typing import Any, Callable, Coroutine

from google.genai import types

from app.tools.stock_tools import get_stock_tools


# Tool function type
ToolFunction = Callable[..., Coroutine[Any, Any, Any]]


class ToolRegistry:
    """Registry of available tools for agents."""

    # Tool definitions in Gemini function declaration format
    TOOL_DECLARATIONS = [
        types.FunctionDeclaration(
            name="get_stock_quote",
            description="Get the current stock price, market cap, P/E ratio, and other key metrics for a given stock symbol. Use this when discussing specific stocks or when the user asks about stock prices.",
            parameters={
                "type": "object",
                "properties": {
                    "symbol": {
                        "type": "string",
                        "description": "The stock ticker symbol (e.g., 'AAPL' for Apple, 'GOOGL' for Google, 'MSFT' for Microsoft)",
                    }
                },
                "required": ["symbol"],
            },
        ),
        types.FunctionDeclaration(
            name="get_stock_news",
            description="Get recent financial news and headlines for a specific stock. Use this to understand recent events affecting a company.",
            parameters={
                "type": "object",
                "properties": {
                    "symbol": {
                        "type": "string",
                        "description": "The stock ticker symbol to get news for",
                    }
                },
                "required": ["symbol"],
            },
        ),
        types.FunctionDeclaration(
            name="get_market_summary",
            description="Get a summary of major market indices (S&P 500, NASDAQ, DOW). Use this to understand overall market conditions.",
            parameters={
                "type": "object",
                "properties": {},
            },
        ),
    ]

    @classmethod
    def get_gemini_tools(cls) -> list[types.Tool]:
        """Get tools in Gemini format."""
        return [types.Tool(function_declarations=cls.TOOL_DECLARATIONS)]

    @classmethod
    async def execute_tool(cls, name: str, args: dict) -> Any:
        """Execute a tool by name with given arguments.
        
        Args:
            name: Tool function name
            args: Arguments to pass to the tool
            
        Returns:
            Tool execution result
        """
        tools = get_stock_tools()
        
        handlers: dict[str, ToolFunction] = {
            "get_stock_quote": tools.get_stock_quote,
            "get_stock_news": tools.get_stock_news,
            "get_market_summary": tools.get_market_summary,
        }
        
        handler = handlers.get(name)
        if not handler:
            raise ValueError(f"Unknown tool: {name}")
        
        return await handler(**args)


# Investment-related tools for the investment advisor
INVESTMENT_TOOLS = ToolRegistry.get_gemini_tools()
