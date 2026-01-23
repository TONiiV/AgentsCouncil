"""
AgentsCouncil Backend - Stock Market Tools

Provides stock quote, news, and market data tools for the investment agent.
Uses yfinance for stock data and langchain-community for tool abstractions.
"""
import logging
from typing import Any

import yfinance as yf
from langchain_community.tools.yahoo_finance_news import YahooFinanceNewsTool

logger = logging.getLogger(__name__)


class StockTools:
    """Stock market tools for investment agents."""

    def __init__(self):
        self._news_tool = YahooFinanceNewsTool()

    async def get_stock_quote(self, symbol: str) -> dict[str, Any]:
        """Get current stock quote and key metrics.
        
        Args:
            symbol: Stock ticker symbol (e.g., 'AAPL', 'GOOGL')
            
        Returns:
            Dict with price, change, volume, market cap, and other metrics
        """
        try:
            ticker = yf.Ticker(symbol.upper())
            info = ticker.info
            
            # Get fast info for current price
            fast_info = ticker.fast_info
            
            return {
                "symbol": symbol.upper(),
                "name": info.get("shortName", info.get("longName", symbol)),
                "current_price": fast_info.get("lastPrice", info.get("currentPrice")),
                "previous_close": info.get("previousClose"),
                "open": info.get("open"),
                "day_high": info.get("dayHigh"),
                "day_low": info.get("dayLow"),
                "volume": fast_info.get("lastVolume", info.get("volume")),
                "market_cap": fast_info.get("marketCap", info.get("marketCap")),
                "pe_ratio": info.get("trailingPE"),
                "fifty_two_week_high": info.get("fiftyTwoWeekHigh"),
                "fifty_two_week_low": info.get("fiftyTwoWeekLow"),
                "dividend_yield": info.get("dividendYield"),
                "sector": info.get("sector"),
                "industry": info.get("industry"),
            }
        except Exception as e:
            logger.error(f"Error fetching quote for {symbol}: {e}")
            return {"symbol": symbol, "error": str(e)}

    async def get_stock_news(self, symbol: str) -> str:
        """Get recent news for a stock.
        
        Args:
            symbol: Stock ticker symbol
            
        Returns:
            News summary as a string
        """
        try:
            # Use LangChain's Yahoo Finance News tool
            result = self._news_tool.invoke(symbol.upper())
            return result
        except Exception as e:
            logger.error(f"Error fetching news for {symbol}: {e}")
            return f"Unable to fetch news for {symbol}: {e}"

    async def get_market_summary(self) -> dict[str, Any]:
        """Get summary of major market indices.
        
        Returns:
            Dict with S&P 500, NASDAQ, and DOW data
        """
        indices = {
            "sp500": "^GSPC",
            "nasdaq": "^IXIC",
            "dow": "^DJI",
        }
        
        summary = {}
        for name, symbol in indices.items():
            try:
                ticker = yf.Ticker(symbol)
                fast_info = ticker.fast_info
                info = ticker.info
                
                summary[name] = {
                    "name": info.get("shortName", name.upper()),
                    "price": fast_info.get("lastPrice"),
                    "change": fast_info.get("lastPrice", 0) - info.get("previousClose", 0),
                    "change_percent": (
                        (fast_info.get("lastPrice", 0) - info.get("previousClose", 1)) 
                        / info.get("previousClose", 1) * 100
                    ) if info.get("previousClose") else None,
                }
            except Exception as e:
                logger.error(f"Error fetching {name}: {e}")
                summary[name] = {"error": str(e)}
        
        return summary


# Singleton instance
_stock_tools: StockTools | None = None


def get_stock_tools() -> StockTools:
    """Get singleton StockTools instance."""
    global _stock_tools
    if _stock_tools is None:
        _stock_tools = StockTools()
    return _stock_tools
