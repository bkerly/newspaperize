library(shiny)
library(rvest)
library(httr)
library(rmarkdown)
library(tinytex)
library(bslib)

ui <- page_sidebar(
    theme = bs_theme(bootswatch = "cosmo"),
    title = tags$span(
        tags$span("📰", style = "font-size: 1.2em; margin-right: 8px;"),
        "Mini Newspaper Generator"
    ),
    
    sidebar = sidebar(
        width = 350,
        textAreaInput("urls", 
                      "Article URLs (one per line):",
                      height = "200px",
                      placeholder = "https://example.com/article1\nhttps://example.com/article2"),
        textInput("newspaper_title", "Newspaper Title:", value = "The Daily Brief"),
        selectInput("columns", "Number of Columns:", choices = c(2, 3), selected = 2),
        checkboxInput("include_images", "Include Images", value = FALSE),
        actionButton("generate", "Generate Newspaper", class = "btn-primary w-100"),
        hr(),
        downloadButton("download_pdf", "Download PDF", class = "w-100")
    ),
    
    card(
        card_header(
            tags$span(
                tags$span("📋", style = "margin-right: 8px;"),
                "Preview & Diagnostics"
            )
        ),
        verbatimTextOutput("debug_info"),
        hr(),
        uiOutput("preview")
    )
)

server <- function(input, output, session) {
    
    articles <- reactiveVal(list())
    
    # Function to clean text for LaTeX
    clean_latex <- function(text) {
        if(is.null(text) || is.na(text) || text == "") return("")
        
        # First, convert to UTF-8 and remove problematic characters
        text <- iconv(text, to = "UTF-8", sub = "")
        
        # Remove or replace special unicode characters that cause issues
        text <- gsub("[\u2018\u2019]", "'", text)  # Smart single quotes
        text <- gsub("[\u201C\u201D]", '"', text)  # Smart double quotes
        text <- gsub("\u2013", "--", text)         # En dash
        text <- gsub("\u2014", "---", text)        # Em dash
        text <- gsub("\u2026", "...", text)        # Ellipsis
        text <- gsub("[\u2022\u2023\u25E6\u2043\u2219]", "-", text)  # Bullets
        
        # Escape LaTeX special characters (order matters!)
        # Do # first before it gets confused with other escapes
        text <- gsub("#", "\\\\#", text)
        text <- gsub("\\\\(?!#)", "\\\\textbackslash{}", text, perl = TRUE)
        text <- gsub("([&%$_{}])", "\\\\\\1", text)
        text <- gsub("~", "\\\\textasciitilde{}", text)
        text <- gsub("\\^", "\\\\textasciicircum{}", text)
        text <- gsub("<", "\\\\textless{}", text)
        text <- gsub(">", "\\\\textgreater{}", text)
        text <- gsub("\\|", "\\\\textbar{}", text)
        
        # Remove any remaining problematic characters
        text <- gsub("[^\x20-\x7E\n]", "", text)
        
        text
    }
    
    # Function to download image
    download_image <- function(url, dest_dir) {
        tryCatch({
            ext <- tools::file_ext(url)
            if(ext == "") ext <- "jpg"
            if(!ext %in% c("jpg", "jpeg", "png", "gif")) ext <- "jpg"
            
            dest_file <- file.path(dest_dir, paste0("img_", digest::digest(url), ".", ext))
            
            response <- GET(url, timeout(10))
            if(status_code(response) == 200) {
                writeBin(content(response, "raw"), dest_file)
                return(dest_file)
            }
            return(NULL)
        }, error = function(e) {
            return(NULL)
        })
    }
    
    # Function to extract article content with image positions
    extract_article <- function(url) {
        tryCatch({
            # Fetch with proper headers
            response <- GET(url, 
                            user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"),
                            timeout(30))
            
            if(status_code(response) != 200) {
                return(list(
                    title = "Error",
                    content = paste("HTTP error:", status_code(response)),
                    content_with_images = "",
                    images = character(0),
                    url = url,
                    success = FALSE
                ))
            }
            
            page <- read_html(content(response, "text", encoding = "UTF-8"))
            
            # Extract title
            title <- page %>% 
                html_nodes("h1") %>%
                html_text() %>%
                .[1] %>%
                trimws()
            
            if(is.na(title) || title == "") title <- "Untitled Article"
            
            # Get main content area nodes (includes both text and images in order)
            content_nodes <- page %>%
                html_nodes("article *, main *, .post-content *, .entry-content *")
            
            content_pieces <- list()
            image_urls <- c()
            
            for(node in content_nodes) {
                node_name <- html_name(node)
                
                # Handle images
                if(node_name == "img") {
                    img_src <- html_attr(node, "src")
                    if(!is.na(img_src) && !grepl("w_80|h_80|32x32|icon|logo|avatar", img_src, ignore.case = TRUE)) {
                        # Convert to absolute URL
                        if(grepl("^http", img_src)) {
                            img_url <- img_src
                        } else if(grepl("^//", img_src)) {
                            img_url <- paste0("https:", img_src)
                        } else {
                            img_url <- xml2::url_absolute(img_src, url)
                        }
                        
                        # Add image marker
                        content_pieces[[length(content_pieces) + 1]] <- list(
                            type = "image",
                            content = img_url
                        )
                        image_urls <- c(image_urls, img_url)
                    }
                    next
                }
                
                # Handle text content
                if(node_name %in% c("h2", "h3", "h4", "h5", "h6", "p")) {
                    text <- html_text(node) %>% trimws()
                    
                    # Skip very short text, navigation, and common footer elements
                    if(nchar(text) < 10) next
                    if(grepl("^(Share|Subscribe|Sign in|Comments?|Restacks?|Top|Latest|Previous|Ready for more)", text)) next
                    if(grepl("twitter\\.com|facebook\\.com|@", text)) next
                    if(grepl("^©|Privacy|Terms|Collection notice", text)) next
                    
                    content_pieces[[length(content_pieces) + 1]] <- list(
                        type = "text",
                        content = text
                    )
                }
            }
            
            # Build content string (text only for preview)
            text_only <- sapply(content_pieces, function(piece) {
                if(piece$type == "text") piece$content else ""
            })
            content <- paste(text_only[text_only != ""], collapse = "\n\n")
            
            # Fallback if we got very little
            if(nchar(content) < 500) {
                content <- page %>%
                    html_nodes("p") %>%
                    html_text() %>%
                    trimws() %>%
                    paste(collapse = "\n\n")
            }
            
            list(
                title = title,
                content = substr(content, 1, 60000),
                content_pieces = content_pieces,  # Preserve structure with images
                images = head(image_urls, 10),  # Limit total images
                url = url,
                success = TRUE,
                char_count = nchar(content),
                word_count = length(strsplit(content, "\\s+")[[1]])
            )
        }, error = function(e) {
            list(
                title = "Error",
                content = paste("Failed to extract article:", e$message),
                content_pieces = list(),
                images = character(0),
                url = url,
                success = FALSE,
                char_count = 0,
                word_count = 0
            )
        })
    }
    
    observeEvent(input$generate, {
        req(input$urls)
        
        urls <- strsplit(input$urls, "\n")[[1]]
        urls <- trimws(urls[urls != ""])
        
        if(length(urls) == 0) {
            showNotification("Please enter at least one URL", type = "warning")
            return()
        }
        
        showNotification("Fetching articles...", duration = NULL, id = "fetching")
        
        article_list <- lapply(urls, extract_article)
        articles(article_list)
        
        removeNotification("fetching")
        showNotification("Articles fetched successfully!", type = "message")
    })
    
    output$debug_info <- renderText({
        req(articles())
        
        debug_lines <- sapply(seq_along(articles()), function(i) {
            art <- articles()[[i]]
            paste0("Article ", i, ": ", 
                   art$title, "\n",
                   "  Characters: ", art$char_count, 
                   " | Words: ", art$word_count,
                   " | Success: ", art$success)
        })
        
        paste(debug_lines, collapse = "\n\n")
    })
    
    output$preview <- renderUI({
        req(articles())
        
        article_cards <- lapply(articles(), function(art) {
            if(art$success) {
                tagList(
                    tags$div(
                        class = "border rounded p-3 mb-3",
                        tags$h4(art$title),
                        tags$p(class = "text-muted small", art$url),
                        tags$p(class = "badge bg-info", 
                               paste0(art$char_count, " chars, ", art$word_count, " words")),
                        tags$p(substr(art$content, 1, 500), "...")
                    )
                )
            } else {
                tags$div(
                    class = "border border-danger rounded p-3 mb-3",
                    tags$h4(class = "text-danger", "Error"),
                    tags$p(art$content)
                )
            }
        })
        
        tagList(article_cards)
    })
    
    output$download_pdf <- downloadHandler(
        filename = function() {
            paste0(gsub(" ", "_", input$newspaper_title), "_", Sys.Date(), ".pdf")
        },
        content = function(file) {
            req(articles())
            
            showNotification("Generating PDF...", duration = NULL, id = "pdf_gen")
            
            # Create temporary directory for images
            temp_dir <- tempdir()
            img_dir <- file.path(temp_dir, "newspaper_imgs")
            dir.create(img_dir, showWarnings = FALSE, recursive = TRUE)
            
            # Create temporary Rmd file
            temp_rmd <- tempfile(fileext = ".Rmd")
            
            # Build Rmd content
            rmd_content <- paste0(
                "---\n",
                "title: \"", clean_latex(input$newspaper_title), "\"\n",
                "date: \"", format(Sys.Date(), "%B %d, %Y"), "\"\n",
                "output:\n",
                "  pdf_document:\n",
                "    latex_engine: pdflatex\n",
                "    keep_tex: false\n",
                "geometry: margin=0.5in\n",
                if(input$columns == "2") "classoption: twocolumn\n" else "",
                "header-includes:\n",
                if(input$columns == "3") "  - \\usepackage{multicol}\n" else "",
                "  - \\usepackage{graphicx}\n",
                "  - \\usepackage{fancyhdr}\n",
                "  - \\setlength{\\headheight}{22.49pt}\n",
                "  - \\addtolength{\\topmargin}{-10.49pt}\n",
                "  - \\pagestyle{fancy}\n",
                "  - \\setlength{\\columnsep}{15pt}\n",
                "  - \\usepackage[utf8]{inputenc}\n",
                if(input$columns == "2") "  - \\usepackage{ragged2e}\n" else "",
                "---\n\n"
            )
            
            # Only use RaggedRight for 2-column layout
            if(input$columns == "2") {
                rmd_content <- paste0(rmd_content, "\\RaggedRight\n\n")
            }
            
            # Start 3-column environment if needed
            if(input$columns == "3") {
                rmd_content <- paste0(rmd_content, "\\begin{multicols}{3}\n\n")
            }
            
            # Add articles
            for(art in articles()) {
                if(art$success && nchar(art$content) > 0) {
                    clean_title <- clean_latex(art$title)
                    
                    # For 3-column, use LaTeX subsection directly to avoid markdown parsing issues
                    if(input$columns == "3") {
                        rmd_content <- paste0(rmd_content, "\\subsection*{", clean_title, "}\n\n")
                    } else {
                        rmd_content <- paste0(rmd_content, "# ", clean_title, "\n\n")
                    }
                    
                    # If images are enabled and we have structured content, use it
                    if(input$include_images && length(art$content_pieces) > 0) {
                        char_count <- 0
                        img_count <- 0
                        max_chars <- 60000
                        max_imgs <- 5
                        
                        for(piece in art$content_pieces) {
                            if(char_count >= max_chars) break
                            
                            if(piece$type == "text") {
                                clean_text <- clean_latex(piece$content)
                                if(nchar(clean_text) > 0) {
                                    rmd_content <- paste0(rmd_content, clean_text, "\n\n")
                                    char_count <- char_count + nchar(clean_text)
                                }
                            } else if(piece$type == "image" && img_count < max_imgs) {
                                local_img <- download_image(piece$content, img_dir)
                                if(!is.null(local_img) && file.exists(local_img)) {
                                    rel_path <- normalizePath(local_img)
                                    # Use linewidth for full column width
                                    rmd_content <- paste0(rmd_content, 
                                                          "\\noindent\\includegraphics[width=\\linewidth]{", rel_path, "}\n\n")
                                    img_count <- img_count + 1
                                }
                            }
                        }
                    } else {
                        # No images or structured content not available - use plain text
                        clean_content <- clean_latex(art$content)
                        
                        if(nchar(clean_content) == 0) next
                        
                        paragraphs <- strsplit(clean_content, "\n\n")[[1]]
                        paragraphs <- paragraphs[nchar(trimws(paragraphs)) > 0]
                        
                        paragraphs <- sapply(paragraphs, function(p) {
                            if(nchar(p) > 5000) substr(p, 1, 5000) else p
                        })
                        
                        formatted_content <- paste(paragraphs, collapse = "\n\n")
                        rmd_content <- paste0(rmd_content, formatted_content, "\n\n")
                    }
                    
                    rmd_content <- paste0(rmd_content, "\\vspace{0.2cm}\n\n")
                    
                    # Only add hrule for 2-column layout (can cause issues in 3-column)
                    if(input$columns == "2") {
                        rmd_content <- paste0(rmd_content, "\\hrulefill\n\n")
                    } else {
                        rmd_content <- paste0(rmd_content, "\\vspace{0.1cm}\n\n")
                    }
                }
            }
            
            if(input$columns == "3") {
                rmd_content <- paste0(rmd_content, "\\end{multicols}\n")
            }
            
            writeLines(rmd_content, temp_rmd)
            
            # Render to PDF
            tryCatch({
                rmarkdown::render(
                    temp_rmd,
                    output_file = file,
                    quiet = FALSE
                )
                removeNotification("pdf_gen")
                showNotification("PDF generated successfully!", type = "message")
            }, error = function(e) {
                removeNotification("pdf_gen")
                showNotification(paste("PDF generation failed:", e$message), 
                                 type = "error", duration = 15)
            })
            
            # Cleanup
            unlink(img_dir, recursive = TRUE)
        }
    )
}

shinyApp(ui, server)