"""
Tests for Stock Market Tools
"""
import pytest
from unittest.mock import MagicMock, patch
from app.tools.stock_tools import StockTools

class TestStockTools:
    
    @pytest.fixture
    def stock_tools(self):
        return StockTools()

    @pytest.mark.asyncio
    async def test_get_stock_quote_valid(self, stock_tools):
        """Test get_stock_quote with a valid symbol."""
        with patch('yfinance.Ticker') as mock_ticker_class:
            mock_ticker = MagicMock()
            mock_ticker_class.return_value = mock_ticker
            
            mock_ticker.info = {
                "shortName": "Apple Inc.",
                "currentPrice": 220.50,
                "previousClose": 218.00,
                "volume": 50000000,
                "marketCap": 3000000000000,
                "sector": "Technology"
            }
            # Mock fast_info as an object with get() method
            mock_fast_info = MagicMock()
            mock_fast_info.get.side_effect = lambda k, default=None: {
                "lastPrice": 220.50,
                "lastVolume": 50000000,
                "marketCap": 3000000000000
            }.get(k, default)
            mock_ticker.fast_info = mock_fast_info
            
            result = await stock_tools.get_stock_quote("AAPL")
            
            assert result["symbol"] == "AAPL"
            assert result["name"] == "Apple Inc."
            assert result["current_price"] == 220.50
            assert result["sector"] == "Technology"

    @pytest.mark.asyncio
    async def test_get_stock_news(self, stock_tools):
        """Test get_stock_news with mocked news tool."""
        # Patch the class in the module where it's used
        with patch('app.tools.stock_tools.YahooFinanceNewsTool') as mock_tool_class:
            mock_tool_instance = MagicMock()
            mock_tool_class.return_value = mock_tool_instance
            mock_tool_instance.invoke.return_value = "Recent news: Apple releases iPhone 16"
            
            # Re-initialize to pick up the mocked class if needed, or just set it
            stock_tools._news_tool = mock_tool_instance
            
            result = await stock_tools.get_stock_news("AAPL")
            assert "Recent news" in result
            mock_tool_instance.invoke.assert_called_once_with("AAPL")

    @pytest.mark.asyncio
    async def test_get_market_summary(self, stock_tools):
        """Test get_market_summary."""
        with patch('yfinance.Ticker') as mock_ticker_class:
            mock_ticker = MagicMock()
            mock_ticker_class.return_value = mock_ticker
            
            mock_ticker.info = {"shortName": "S&P 500", "previousClose": 5000}
            # Mock fast_info for market summary too
            mock_fast_info = MagicMock()
            mock_fast_info.get.side_effect = lambda k, default=None: {
                "lastPrice": 5050,
            }.get(k, default)
            mock_ticker.fast_info = mock_fast_info
            
            result = await stock_tools.get_market_summary()
            
            assert "sp500" in result
            assert "nasdaq" in result
            assert "dow" in result
            assert result["sp500"]["price"] == 5050
            assert result["sp500"]["change"] == 50.0
