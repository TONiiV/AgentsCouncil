"""
Tests for Tool Registry
"""

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from app.tools.registry import ToolRegistry


class TestToolRegistry:
    def test_get_gemini_tools(self):
        """Test tool definitions for Gemini."""
        tools = ToolRegistry.get_gemini_tools()
        assert len(tools) == 1
        assert len(tools[0].function_declarations) == 3

        names = [fd.name for fd in tools[0].function_declarations]
        assert "get_stock_quote" in names
        assert "get_stock_news" in names
        assert "get_market_summary" in names

    @pytest.mark.asyncio
    async def test_execute_tool_quote(self):
        """Test tool execution by name."""
        with patch("app.tools.registry.get_stock_tools") as mock_get_tools:
            mock_tools = MagicMock()
            mock_get_tools.return_value = mock_tools
            mock_tools.get_stock_quote = AsyncMock(return_value={"price": 100})

            result = await ToolRegistry.execute_tool("get_stock_quote", {"symbol": "TSLA"})

            assert result["price"] == 100
            mock_tools.get_stock_quote.assert_called_once_with(symbol="TSLA")

    @pytest.mark.asyncio
    async def test_execute_tool_news(self):
        """Test executing get_stock_news tool."""
        with patch("app.tools.registry.get_stock_tools") as mock_get_tools:
            mock_tools = MagicMock()
            mock_get_tools.return_value = mock_tools
            mock_news = [{"title": " Earnings Report", "source": "TestSource"}]
            mock_tools.get_stock_news = AsyncMock(return_value=mock_news)

            result = await ToolRegistry.execute_tool("get_stock_news", {"symbol": "AAPL"})

            assert len(result) == 1
            assert result[0]["title"] == " Earnings Report"
            mock_tools.get_stock_news.assert_called_once_with(symbol="AAPL")

    @pytest.mark.asyncio
    async def test_execute_tool_market_summary(self):
        """Test executing get_market_summary tool."""
        with patch("app.tools.registry.get_stock_tools") as mock_get_tools:
            mock_tools = MagicMock()
            mock_get_tools.return_value = mock_tools
            mock_summary = {"sp500": 4500.0, "nasdaq": 14000.0}
            mock_tools.get_market_summary = AsyncMock(return_value=mock_summary)

            result = await ToolRegistry.execute_tool("get_market_summary", {})

            assert result["sp500"] == 4500.0
            mock_tools.get_market_summary.assert_called_once_with()

    @pytest.mark.asyncio
    async def test_execute_unknown_tool(self):
        """Test executing unknown tool raises ValueError."""
        with patch("app.tools.registry.get_stock_tools") as mock_get_tools:
            mock_get_tools.return_value = MagicMock()

            with pytest.raises(ValueError, match="Unknown tool: nonexistent_tool"):
                await ToolRegistry.execute_tool("nonexistent_tool", {"arg": "value"})

    def test_tool_declarations_have_required_fields(self):
        """Test that all tool declarations have required description and parameters."""
        tools = ToolRegistry.get_gemini_tools()

        for tool in tools:
            func_decls = tool.function_declarations
            assert func_decls, "Tool has no function declarations"

            for fd in func_decls:
                assert hasattr(fd, "name"), f"Function declaration missing name"
                assert fd.name, f"Function declaration {fd.name} has empty name"
                assert hasattr(fd, "description"), (
                    f"Function declaration {fd.name} missing description"
                )
                assert fd.description, f"Function declaration {fd.name} has empty description"
                assert hasattr(fd, "parameters"), (
                    f"Function declaration {fd.name} missing parameters"
                )

    def test_stock_quote_tool_schema(self):
        """Test that get_stock_quote tool has correct schema."""
        tools = ToolRegistry.get_gemini_tools()
        quote_tool = None
        for tool in tools:
            for fd in tool.function_declarations or []:
                if fd.name == "get_stock_quote":
                    quote_tool = fd
                    break

        assert quote_tool is not None, "get_stock_quote tool not found"
        assert quote_tool.name == "get_stock_quote"
        assert hasattr(quote_tool, "description")
        assert (
            "symbol" in quote_tool.description.lower() or "ticker" in quote_tool.description.lower()
        )

    def test_all_tools_return_proper_types(self):
        """Test that tools list has correct structure."""
        tools = ToolRegistry.get_gemini_tools()

        assert isinstance(tools, list)
        assert len(tools) == 1
        assert hasattr(tools[0], "function_declarations")
        assert len(tools[0].function_declarations) == 3

    @pytest.mark.asyncio
    async def test_execute_tool_with_empty_args(self):
        """Test tool execution with empty arguments when no args needed."""
        with patch("app.tools.registry.get_stock_tools") as mock_get_tools:
            mock_tools = MagicMock()
            mock_get_tools.return_value = mock_tools
            mock_tools.get_market_summary = AsyncMock(return_value={})

            result = await ToolRegistry.execute_tool("get_market_summary", {})

            assert result == {}
            mock_tools.get_market_summary.assert_called_once()

    @pytest.mark.asyncio
    async def test_execute_tool_exception_handling(self):
        """Test that tool exceptions are properly propagated."""
        with patch("app.tools.registry.get_stock_tools") as mock_get_tools:
            mock_tools = MagicMock()
            mock_get_tools.return_value = mock_tools
            mock_tools.get_stock_quote = AsyncMock(side_effect=Exception("API error"))

            with pytest.raises(Exception, match="API error"):
                await ToolRegistry.execute_tool("get_stock_quote", {"symbol": "INVALID"})
