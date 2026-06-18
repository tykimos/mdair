#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

NSString *codeCopyButtonHTML(void) {
    return @"<button class=\"mdair-copy-button\" type=\"button\" aria-label=\"Copy code\" title=\"Copy code\"><svg class=\"mdair-copy-icon\" viewBox=\"0 0 16 16\" aria-hidden=\"true\"><path d=\"M5 4.5A1.5 1.5 0 0 1 6.5 3h5A1.5 1.5 0 0 1 13 4.5v7a1.5 1.5 0 0 1-1.5 1.5h-5A1.5 1.5 0 0 1 5 11.5v-7Z\"/><path d=\"M3 10.5V3.75A1.75 1.75 0 0 1 4.75 2H10\"/></svg></button>";
}

NSString *getCopyScript(void) {
    return @"<script>(function(){var copyIcon='<svg class=\"mdair-copy-icon\" viewBox=\"0 0 16 16\" aria-hidden=\"true\"><path d=\"M5 4.5A1.5 1.5 0 0 1 6.5 3h5A1.5 1.5 0 0 1 13 4.5v7a1.5 1.5 0 0 1-1.5 1.5h-5A1.5 1.5 0 0 1 5 11.5v-7Z\"/><path d=\"M3 10.5V3.75A1.75 1.75 0 0 1 4.75 2H10\"/></svg>';function resetButton(button){button.classList.remove('copied');button.setAttribute('aria-label','Copy code');button.title='Copy code';button.innerHTML=copyIcon;}function markCopied(button){if(!button)return;button.classList.add('copied');button.setAttribute('aria-label','Copied');button.title='Copied';button.textContent='Copied';clearTimeout(button.__mdairCopyTimeout);button.__mdairCopyTimeout=setTimeout(function(){resetButton(button);},1400);}function fallbackCopy(text,done){var textarea=document.createElement('textarea');textarea.value=text;textarea.setAttribute('readonly','');textarea.style.position='fixed';textarea.style.top='0';textarea.style.left='0';textarea.style.opacity='0';document.body.appendChild(textarea);textarea.select();try{document.execCommand('copy');}catch(e){}document.body.removeChild(textarea);done();}function copyText(text,button){if(text==null)return;var done=function(){markCopied(button);};if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(text).then(done,function(){fallbackCopy(text,done);});}else{fallbackCopy(text,done);}}function installCopyButtons(){document.querySelectorAll('pre > code').forEach(function(code){var pre=code.parentElement;if(!pre||pre.classList.contains('mermaid'))return;var wrapper=code.closest('.mdair-code-block');if(!wrapper){wrapper=document.createElement('div');wrapper.className='mdair-code-block';pre.parentNode.insertBefore(wrapper,pre);wrapper.appendChild(pre);}var button=wrapper.querySelector('.mdair-copy-button');if(!button){button=document.createElement('button');button.type='button';button.className='mdair-copy-button';wrapper.insertBefore(button,wrapper.firstChild);}if(!button.querySelector('.mdair-copy-icon')&&!button.classList.contains('copied'))resetButton(button);if(button.dataset.mdairCopyReady==='1')return;button.dataset.mdairCopyReady='1';button.addEventListener('click',function(){copyText(code.textContent,button);});});}document.addEventListener('DOMContentLoaded',installCopyButtons);if(document.readyState==='complete'||document.readyState==='interactive')installCopyButtons();})();</script>";
}

// Simple Markdown to HTML converter
NSString *markdownToHTML(NSString *markdown) {
    NSMutableString *html = [markdown mutableCopy];
    NSMutableArray *mermaidBlocks = [NSMutableArray array];

    // Fenced code blocks (``` ... ```) — must be processed before inline patterns
    {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"```(\\w*)\\n([\\s\\S]*?)```"
                                                                               options:0 error:nil];
        NSArray *matches = [regex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        // Process in reverse to maintain ranges
        for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
            NSString *lang = [html substringWithRange:[match rangeAtIndex:1]];
            NSString *code = [html substringWithRange:[match rangeAtIndex:2]];
            NSString *replacement;
            if ([lang isEqualToString:@"mermaid"]) {
                NSString *placeholder = [NSString stringWithFormat:@"<!--MERMAID_%lu-->", (unsigned long)mermaidBlocks.count];
                [mermaidBlocks addObject:code];
                replacement = placeholder;
            } else {
                // Escape HTML entities in code
                code = [code stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
                code = [code stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
                code = [code stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
                replacement = [NSString stringWithFormat:@"<div class=\"mdair-code-block\">%@<pre><code>%@</code></pre></div>", codeCopyButtonHTML(), code];
            }
            [html replaceCharactersInRange:[match range] withString:replacement];
        }
    }

    // Process line by line for block elements
    NSArray *lines = [html componentsSeparatedByString:@"\n"];
    NSMutableArray *outputLines = [NSMutableArray array];
    BOOL inList = NO;
    BOOL inOrderedList = NO;
    BOOL inBlockquote = NO;
    BOOL inTable = NO;
    BOOL inPre = NO;

    for (NSString *line in lines) {
        // Skip processing inside pre blocks
        if ([line containsString:@"<pre>"]) inPre = YES;
        if ([line containsString:@"</pre>"]) { inPre = NO; [outputLines addObject:line]; continue; }
        if (inPre) { [outputLines addObject:line]; continue; }

        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        // Horizontal rule
        if ([trimmed isEqualToString:@"---"] || [trimmed isEqualToString:@"***"] || [trimmed isEqualToString:@"___"]) {
            if (inList) { [outputLines addObject:@"</ul>"]; inList = NO; }
            if (inOrderedList) { [outputLines addObject:@"</ol>"]; inOrderedList = NO; }
            if (inBlockquote) { [outputLines addObject:@"</blockquote>"]; inBlockquote = NO; }
            [outputLines addObject:@"<hr>"];
            continue;
        }

        // Headings
        if ([trimmed hasPrefix:@"###### "]) {
            [outputLines addObject:[NSString stringWithFormat:@"<h6>%@</h6>", [trimmed substringFromIndex:7]]];
            continue;
        }
        if ([trimmed hasPrefix:@"##### "]) {
            [outputLines addObject:[NSString stringWithFormat:@"<h5>%@</h5>", [trimmed substringFromIndex:6]]];
            continue;
        }
        if ([trimmed hasPrefix:@"#### "]) {
            [outputLines addObject:[NSString stringWithFormat:@"<h4>%@</h4>", [trimmed substringFromIndex:5]]];
            continue;
        }
        if ([trimmed hasPrefix:@"### "]) {
            [outputLines addObject:[NSString stringWithFormat:@"<h3>%@</h3>", [trimmed substringFromIndex:4]]];
            continue;
        }
        if ([trimmed hasPrefix:@"## "]) {
            [outputLines addObject:[NSString stringWithFormat:@"<h2>%@</h2>", [trimmed substringFromIndex:3]]];
            continue;
        }
        if ([trimmed hasPrefix:@"# "]) {
            [outputLines addObject:[NSString stringWithFormat:@"<h1>%@</h1>", [trimmed substringFromIndex:2]]];
            continue;
        }

        // Blockquote
        if ([trimmed hasPrefix:@"> "]) {
            if (!inBlockquote) {
                [outputLines addObject:@"<blockquote>"];
                inBlockquote = YES;
            }
            [outputLines addObject:[trimmed substringFromIndex:2]];
            continue;
        } else if (inBlockquote) {
            [outputLines addObject:@"</blockquote>"];
            inBlockquote = NO;
        }

        // Table detection (pipes)
        if ([trimmed containsString:@"|"] && [trimmed hasPrefix:@"|"]) {
            // Skip separator rows
            NSString *cleaned = [trimmed stringByReplacingOccurrencesOfString:@"-" withString:@""];
            cleaned = [cleaned stringByReplacingOccurrencesOfString:@"|" withString:@""];
            cleaned = [cleaned stringByReplacingOccurrencesOfString:@":" withString:@""];
            cleaned = [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (cleaned.length == 0) continue; // separator row

            if (!inTable) {
                [outputLines addObject:@"<table>"];
                inTable = YES;
                // First row is header
                NSArray *cells = [trimmed componentsSeparatedByString:@"|"];
                NSMutableString *row = [NSMutableString stringWithString:@"<tr>"];
                for (NSString *cell in cells) {
                    NSString *trimmedCell = [cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    if (trimmedCell.length > 0) {
                        [row appendFormat:@"<th>%@</th>", trimmedCell];
                    }
                }
                [row appendString:@"</tr>"];
                [outputLines addObject:row];
            } else {
                NSArray *cells = [trimmed componentsSeparatedByString:@"|"];
                NSMutableString *row = [NSMutableString stringWithString:@"<tr>"];
                for (NSString *cell in cells) {
                    NSString *trimmedCell = [cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    if (trimmedCell.length > 0) {
                        [row appendFormat:@"<td>%@</td>", trimmedCell];
                    }
                }
                [row appendString:@"</tr>"];
                [outputLines addObject:row];
            }
            continue;
        } else if (inTable) {
            [outputLines addObject:@"</table>"];
            inTable = NO;
        }

        // Unordered list
        if ([trimmed hasPrefix:@"- "] || [trimmed hasPrefix:@"* "] || [trimmed hasPrefix:@"+ "]) {
            if (inOrderedList) { [outputLines addObject:@"</ol>"]; inOrderedList = NO; }
            if (!inList) {
                [outputLines addObject:@"<ul>"];
                inList = YES;
            }
            NSString *content = [trimmed substringFromIndex:2];
            // Checkbox support
            if ([content hasPrefix:@"[ ] "]) {
                content = [NSString stringWithFormat:@"<input type='checkbox' disabled> %@", [content substringFromIndex:4]];
            } else if ([content hasPrefix:@"[x] "] || [content hasPrefix:@"[X] "]) {
                content = [NSString stringWithFormat:@"<input type='checkbox' checked disabled> %@", [content substringFromIndex:4]];
            }
            [outputLines addObject:[NSString stringWithFormat:@"<li>%@</li>", content]];
            continue;
        } else if (inList && trimmed.length == 0) {
            [outputLines addObject:@"</ul>"];
            inList = NO;
        }

        // Ordered list
        {
            NSRegularExpression *olRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\d+\\.\\s+(.*)" options:0 error:nil];
            NSTextCheckingResult *olMatch = [olRegex firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
            if (olMatch) {
                if (inList) { [outputLines addObject:@"</ul>"]; inList = NO; }
                if (!inOrderedList) {
                    [outputLines addObject:@"<ol>"];
                    inOrderedList = YES;
                }
                [outputLines addObject:[NSString stringWithFormat:@"<li>%@</li>", [trimmed substringWithRange:[olMatch rangeAtIndex:1]]]];
                continue;
            } else if (inOrderedList && trimmed.length == 0) {
                [outputLines addObject:@"</ol>"];
                inOrderedList = NO;
            }
        }

        // Empty line = paragraph break
        if (trimmed.length == 0) {
            [outputLines addObject:@""];
            continue;
        }

        // Regular paragraph
        [outputLines addObject:[NSString stringWithFormat:@"<p>%@</p>", trimmed]];
    }

    // Close any open tags
    if (inList) [outputLines addObject:@"</ul>"];
    if (inOrderedList) [outputLines addObject:@"</ol>"];
    if (inBlockquote) [outputLines addObject:@"</blockquote>"];
    if (inTable) [outputLines addObject:@"</table>"];

    html = [[outputLines componentsJoinedByString:@"\n"] mutableCopy];

    // Inline formatting (applied after block processing)
    // Bold+Italic
    {
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*\\*(.*?)\\*\\*\\*" options:0 error:nil];
        [r replaceMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@"<strong><em>$1</em></strong>"];
    }
    // Bold
    {
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.*?)\\*\\*" options:0 error:nil];
        [r replaceMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@"<strong>$1</strong>"];
    }
    // Italic
    {
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"\\*(.*?)\\*" options:0 error:nil];
        [r replaceMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@"<em>$1</em>"];
    }
    // Inline code
    {
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"`([^`]+)`" options:0 error:nil];
        [r replaceMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@"<code>$1</code>"];
    }
    // Strikethrough
    {
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"~~(.*?)~~" options:0 error:nil];
        [r replaceMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@"<del>$1</del>"];
    }
    // Links [text](url)
    {
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\(([^)]+)\\)" options:0 error:nil];
        [r replaceMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@"<a href=\"$2\">$1</a>"];
    }
    // Images ![alt](url)
    {
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"!\\[([^\\]]*)\\]\\(([^)]+)\\)" options:0 error:nil];
        [r replaceMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@"<img src=\"$2\" alt=\"$1\" style=\"max-width:100%;\">"];
    }

    // Restore mermaid blocks after inline formatting
    for (NSUInteger i = 0; i < mermaidBlocks.count; i++) {
        NSString *replacement = [NSString stringWithFormat:@"<pre class=\"mermaid\">%@</pre>", mermaidBlocks[i]];
        // Try all possible wrapped forms
        NSArray *patterns = @[
            [NSString stringWithFormat:@"<p><!--MERMAID_%lu--></p>", (unsigned long)i],
            [NSString stringWithFormat:@"<!--MERMAID_%lu-->", (unsigned long)i],
            [NSString stringWithFormat:@"<p>&lt;!--MERMAID_%lu--&gt;</p>", (unsigned long)i],
            [NSString stringWithFormat:@"&lt;!--MERMAID_%lu--&gt;", (unsigned long)i],
        ];
        for (NSString *placeholder in patterns) {
            [html replaceOccurrencesOfString:placeholder withString:replacement options:0 range:NSMakeRange(0, html.length)];
        }
    }

    return [html copy];
}

NSString *getCSS(void) {
    return @
    "* { margin: 0; padding: 0; box-sizing: border-box; }"
    ":root { color-scheme: light dark; }"
    "body {"
    "  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;"
    "  max-width: 820px;"
    "  margin: 0 auto;"
    "  padding: 24px 40px;"
    "  line-height: 1.7;"
    "  font-size: 15px;"
    "}"
    "h1 { font-size: 2em; margin: 0.8em 0 0.4em; padding-bottom: 0.3em; border-bottom: 1px solid; }"
    "h2 { font-size: 1.5em; margin: 0.8em 0 0.4em; padding-bottom: 0.2em; border-bottom: 1px solid; }"
    "h3 { font-size: 1.25em; margin: 0.8em 0 0.4em; }"
    "h4 { font-size: 1.1em; margin: 0.6em 0 0.3em; }"
    "h5, h6 { font-size: 1em; margin: 0.6em 0 0.3em; }"
    "p { margin: 0.6em 0; }"
    "pre { padding: 16px; border-radius: 8px; overflow-x: auto; font-size: 13px; margin: 1em 0; }"
    ".mdair-code-block { position: relative; }"
    ".mdair-copy-button {"
    "  position: absolute; top: 10px; right: 10px;"
    "  display: inline-flex; align-items: center; justify-content: center; gap: 4px;"
    "  min-width: 32px; height: 30px;"
    "  opacity: 0; transform: translateY(-2px);"
    "  transition: opacity 0.18s ease, transform 0.18s ease;"
    "  border: none; border-radius: 8px; padding: 0 9px;"
    "  font-size: 12px; background: rgba(0,0,0,0.55); color: #fff;"
    "  cursor: pointer; white-space: nowrap;"
    "}"
    ".mdair-copy-button.copied, .mdair-code-block:hover .mdair-copy-button { opacity: 1; transform: translateY(0); }"
    ".mdair-copy-button:hover { background: rgba(0,0,0,0.74); }"
    ".mdair-copy-icon { width: 15px; height: 15px; }"
    ".mdair-copy-icon path { fill: none; stroke: currentColor; stroke-width: 1.4; stroke-linecap: round; stroke-linejoin: round; }"
    "code { font-family: 'SF Mono', Menlo, monospace; font-size: 0.9em; padding: 2px 6px; border-radius: 4px; }"
    "pre code { padding: 0; font-size: inherit; }"
    "blockquote { padding: 8px 16px; margin: 1em 0; border-left: 4px solid; border-radius: 2px; }"
    "ul, ol { padding-left: 2em; margin: 0.5em 0; }"
    "li { margin: 0.25em 0; }"
    "table { border-collapse: collapse; margin: 1em 0; width: 100%; }"
    "th, td { padding: 8px 12px; border: 1px solid; text-align: left; }"
    "th { font-weight: 600; }"
    "hr { border: none; height: 1px; margin: 2em 0; }"
    "img { max-width: 100%; border-radius: 4px; margin: 0.5em 0; }"
    "a { text-decoration: none; }"
    "a:hover { text-decoration: underline; }"
    "input[type=checkbox] { margin-right: 6px; }"

    // Light theme
    "@media (prefers-color-scheme: light) {"
    "  body { color: #24292f; background: #fff; }"
    "  h1, h2 { border-bottom-color: #d1d9e0; }"
    "  code { background: #eff1f3; }"
    "  pre { background: #f6f8fa; }"
    "  blockquote { border-left-color: #d1d9e0; color: #59636e; background: #f6f8fa; }"
    "  th { background: #f6f8fa; }"
    "  th, td { border-color: #d1d9e0; }"
    "  hr { background: #d1d9e0; }"
    "  a { color: #0969da; }"
    "}"

    // Dark theme
    "@media (prefers-color-scheme: dark) {"
    "  body { color: #e6edf3; background: #0d1117; }"
    "  h1, h2 { border-bottom-color: #30363d; }"
    "  code { background: #262c36; }"
    "  pre { background: #161b22; }"
    "  blockquote { border-left-color: #30363d; color: #8b949e; background: #161b22; }"
    "  th { background: #161b22; }"
    "  th, td { border-color: #30363d; }"
    "  hr { background: #30363d; }"
    "  a { color: #58a6ff; }"
    "}"

    // Print / PDF export — A4 paper with proper margins, readable colors, no awkward breaks
    "@page { size: A4; margin: 18mm 16mm; }"
    "@media print {"
    "  :root { color-scheme: light; }"
    "  html, body {"
    "    color: #24292f !important; background: #fff !important;"
    "    max-width: none !important;"
    "    margin: 0 !important;"
    "    padding: 0 !important;"
    "    font-size: 11pt;"
    "    line-height: 1.55;"
    "    -webkit-print-color-adjust: exact;"
    "    print-color-adjust: exact;"
    "  }"
    "  h1, h2, h3, h4, h5, h6 { page-break-after: avoid; break-after: avoid; }"
    "  h1 { border-bottom-color: #d1d9e0 !important; }"
    "  h2 { border-bottom-color: #d1d9e0 !important; }"
    "  p, li, blockquote { orphans: 3; widows: 3; }"
    "  pre, blockquote, table, figure, img {"
    "    page-break-inside: avoid; break-inside: avoid;"
    "  }"
    "  pre { background: #f6f8fa !important; border: 1px solid #e5e7eb; }"
    "  code { background: #eff1f3 !important; }"
    "  blockquote { background: #f6f8fa !important; border-left-color: #d1d9e0 !important; color: #59636e !important; }"
    "  th { background: #f6f8fa !important; }"
    "  th, td { border-color: #d1d9e0 !important; }"
    "  hr { background: #d1d9e0 !important; }"
    "  a { color: #0969da !important; text-decoration: none; }"
    "  img { max-width: 100% !important; height: auto; }"
    "}";
}

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview,
                                CFURLRef url, CFStringRef contentTypeUTI,
                                CFDictionaryRef options) {
    (void)thisInterface;
    (void)contentTypeUTI;
    (void)options;

    @autoreleasepool {
        if (QLPreviewRequestIsCancelled(preview)) return noErr;

        // Read markdown file
        NSError *error = nil;
        NSString *markdown = [NSString stringWithContentsOfURL:(__bridge NSURL *)url
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
        if (!markdown) {
            // Try other encodings
            markdown = [NSString stringWithContentsOfURL:(__bridge NSURL *)url
                                                encoding:NSISOLatin1StringEncoding
                                                   error:&error];
        }
        if (!markdown) return noErr;

        if (QLPreviewRequestIsCancelled(preview)) return noErr;

        // Convert markdown to HTML
        NSString *body = markdownToHTML(markdown);
        NSString *css = getCSS();
        NSString *html = [NSString stringWithFormat:
            @"<!DOCTYPE html>"
            "<html>"
            "<head>"
            "<meta charset='utf-8'>"
            "<meta name='viewport' content='width=device-width, initial-scale=1'>"
            "<style>%@</style>"
            "</head>"
            "<body>%@"
            "<script src='https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js'></script>"
            "<script>mermaid.initialize({startOnLoad:true,theme:'default'});</script>"
            "%@"
            "</body>"
            "</html>", css, body, getCopyScript()];

        // Return HTML to QuickLook
        NSDictionary *props = @{
            (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey: @"UTF-8",
            (__bridge NSString *)kQLPreviewPropertyMIMETypeKey: @"text/html"
        };

        QLPreviewRequestSetDataRepresentation(preview,
            (__bridge CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding],
            kUTTypeHTML,
            (__bridge CFDictionaryRef)props);
    }

    return noErr;
}

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail,
                                  CFURLRef url, CFStringRef contentTypeUTI,
                                  CFDictionaryRef options, CGSize maxSize) {
    (void)thisInterface;
    (void)thumbnail;
    (void)url;
    (void)contentTypeUTI;
    (void)options;
    (void)maxSize;
    // No thumbnail generation — QuickLook will use default icon
    return noErr;
}
