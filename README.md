# Mini Newspaper Generator

A Shiny app that transforms web articles into beautiful, printable mini newspapers with multiple columns and professional formatting.

## Features

- **URL-based article extraction** - Paste any article URL and automatically extract title, content, and images
- **Multi-column layouts** - Choose between 2 or 3 column newspaper-style formatting
- **PDF generation** - Creates professional, printable PDF documents
- **Image support** - Optionally include inline images from articles
- **Batch processing** - Add multiple articles to create a complete newspaper edition
- **Real-time preview** - See extracted content and diagnostics before generating PDF
- **Character/word count** - Monitor exactly how much content is being extracted
- **Smart content extraction** - Works with Substack, blogs, news sites, and more

## Installation

### Prerequisites

1. **R** (version 4.0 or higher)
2. **LaTeX distribution** - Required for PDF generation

### Install R Packages

```r
install.packages(c(
  "shiny",
  "rvest",
  "httr",
  "rmarkdown",
  "tinytex",
  "bslib",
  "digest",
  "xml2"
))
```

### Install LaTeX

If you don't have LaTeX installed:

```r
tinytex::install_tinytex()
```

This will download and install a minimal LaTeX distribution (~100MB).

## Usage

### Starting the App

1. Save the app code to a file (e.g., `newspaper_app.R`)
2. Open R or RStudio
3. Run:

```r
shiny::runApp("newspaper_app.R")
```

Or in RStudio, simply click the "Run App" button.

### Creating Your Newspaper

1. **Enter URLs** - Paste article URLs into the text box (one per line)
2. **Customize settings**:
   - Set your newspaper title
   - Choose 2 or 3 columns
   - Enable/disable images
3. **Click "Generate Newspaper"** - The app will fetch and extract content
4. **Review diagnostics** - Check character/word counts to ensure content was extracted properly
5. **Download PDF** - Click the download button to generate your mini newspaper

### Example URLs to Try

```
https://www.numlock.com/p/numlock-news-december-11-2025-broadway
https://pluralistic.net/2025/12/05/pop-that-bubble/
https://www.hedgehogreview.com/web-features/thr/posts/the-legacy-of-nicaea
```

## Content Extraction

The app uses intelligent content extraction that:

- Identifies article titles from `<h1>` tags
- Extracts main content from paragraphs and headers
- Filters out navigation, footers, and social media links
- Preserves paragraph breaks for readability
- Handles special characters and unicode for LaTeX compatibility
- Works with most modern website structures

### Supported Sites

Works best with:
- Substack newsletters
- WordPress blogs
- News websites
- Medium posts
- Academic publications
- Most content management systems

May require adjustment for:
- Sites with heavy JavaScript rendering
- Paywalled content (only extracts preview)
- Sites with aggressive anti-scraping measures

## Troubleshooting

### "Failed to extract article"

- Check that the URL is accessible
- Some sites block automated scraping
- Try opening the URL in a browser first to verify it loads

### "LaTeX failed to compile"

- Ensure tinytex is properly installed: `tinytex::reinstall_tinytex()`
- Check the debug output for character counts
- Try disabling images if enabled
- Special characters in content may cause issues (the app attempts to handle these automatically)

### Low character counts in preview

If the app extracts very few characters:
- The site may use JavaScript to load content dynamically
- Try a different article from the same source
- The site structure may not be compatible with the extraction logic

### PDF is truncated

- Check the debug output for actual character counts
- Verify content was fully extracted before PDF generation
- LaTeX column balancing may cause unexpected breaks

## Customization

### Adjusting Content Limits

In the code, modify the character limit (currently 60,000 characters):

```r
content = substr(content, 1, 60000),  # Adjust this number
```

### Changing PDF Layout

Modify the YAML header in the PDF generation section:

```r
geometry: margin=0.5in  # Change margins
\setlength{\columnsep}{15pt}  # Adjust column spacing
```

### Adding Custom Fonts or Styles

Add LaTeX packages to the `header-includes` section of the Rmd generation.

## Future Enhancements

Potential features for future versions:

- **RSS feed integration** - Automatically pull latest articles from feeds
- **Substack API support** - Direct integration with Substack subscriptions
- **Article storage** - Save and manage article collections
- **Custom templates** - Different newspaper styles and layouts
- **Scheduled generation** - Automatic daily/weekly newspaper creation
- **Export formats** - EPUB, HTML, or other formats beyond PDF

## Technical Details

### Architecture

- **Frontend**: Shiny UI with Bootstrap 5 (bslib)
- **Web scraping**: rvest + httr for robust HTTP requests
- **PDF generation**: RMarkdown → LaTeX → PDF pipeline
- **Image handling**: Downloads images locally before PDF compilation

### Content Processing Pipeline

1. HTTP GET request with proper user agent
2. HTML parsing with rvest
3. Content extraction using CSS selectors
4. Text cleaning and LaTeX character escaping
5. Markdown generation with proper formatting
6. LaTeX compilation to PDF
7. Cleanup of temporary files

## License

This project is provided as-is for personal and educational use.

## Contributing

Suggestions and improvements welcome! Common areas for contribution:

- Better content extraction for specific website types
- Additional export formats
- UI/UX improvements
- Performance optimizations
- RSS/feed integration

## Credits

Built with:
- [Shiny](https://shiny.rstudio.com/) - Web application framework
- [rvest](https://rvest.tidyverse.org/) - Web scraping
- [RMarkdown](https://rmarkdown.rstudio.com/) - Document generation
- [TinyTeX](https://yihui.org/tinytex/) - LaTeX distribution

---

**Version**: 1.0  
**Last Updated**: December 2025
