
options(stringsAsFactors=FALSE)

library(plyr)
library(dplyr)
library(reshape2)
library(Rfunctools)
library(pryr)
library(ggplot2)
PopulateEnv("IO", "config_IO.R")
PopulateEnv("fig", "config_fig.R")
PopulateEnv("mylib", c("lib/lib_C_attributes.R", "lib/lib_OSC.R", "lib/lib_metrics.R"))
source("http://ms.mcmaster.ca/~bolker/R/misc/legendx.R")

## -----------------------------------------------------------------------------

DBind[merged.c, merged.g, merged.osc] <- ReadFile(SprintF("props_file", "actual"))

## -----------------------------------------------------------------------------

SelectCase <- function(x)
  x %>% ungroup() %>% filter(case=="ideal") %>% mutate(case=NULL)

## -----------------------------------------------------------------------------

## mass

mass <- SelectCase(merged.c)

ref <- with(mass %>% filter(meas=="full") %>% group_by(variable) %>% summarize(value=sum(value)),
            setNames(value, variable))

mass$value[] <- with(mass, value/ref[as.character(variable)])

cumul <- mass %>%
  filter(meas=="full" & variable=="OC") %>% mutate(meas=NULL, variable=NULL) %>%
  arrange(desc(value)) %>% mutate(value=round(cumsum(value), 2))

## with(cumul, plot(value, type="o"))

clabel.keep <- with(cumul, clabel[1:20])

mass <- mass %>% filter(clabel %in% clabel.keep)

ggplot(mass)+
  geom_bar(aes(meas, value, fill=clabel), stat="identity")+
  facet_grid(.~variable)

## -----------------------------------------------------------------------------

df <- SelectCase(merged.g)

atomr <- df %>% filter(variable!="OM/OC-1")
omoc <- df %>% filter(variable=="OM/OC-1")

cumul <- omoc %>%
  filter(meas=="full") %>% mutate(meas=NULL, variable=NULL) %>%
  arrange(desc(value)) %>% mutate(value=round(cumsum(value)/sum(value), 2))

group.keep <- with(cumul, group[1:8])

atomr <- atomr %>% filter(group %in% group.keep)
omoc <- omoc %>% filter(group %in% group.keep)

## -----------------------------------------------------------------------------

LegendFig <- function(...) {
  plot.new()
  plot.window(0:1, 0:1)
  get("legend", globalenv())(.5, .9, xjust=.5, yjust=1, ..., bty="n", xpd=NA)
}

barplot <- function(...) {
  dotargs <- list(...)
  dotargs$xaxt <- "n"
  dotargs$border <- NA
  bx <- do.call(graphics::barplot, c(dotargs, list(yaxt="n")))
  axis(1,bx,FALSE)
  if(is.null(dotargs$yaxt))
    axis(2, cex.axis=1.4)
  axis(3,bx,FALSE)
  axis(4,,FALSE)
  box()
  text(bx, par("usr")[3]-par("cxy")[2]*.3, adj=c(1, .5),
       colnames(dotargs[[1]]), xpd=NA, srt=30, cex=1.4)
  text(par("usr")[1], par("usr")[4],
       sprintf("%s)", letters[i]), xpd=NA, adj=c(0, -.3), cex=1.4)
  i <<- i+1
}


ylims <- list(
  "OC"=c(0, 1.05),
  "OM"=c(0, 1.05),
  "O/C"=c(0, 1),
  "H/C"=c(0, 2.2),
  "N/C"=c(0, 0.05)
)

colors.C <- with(list(x=unique(mass$clabel)), setNames(GGColorHue(length(x)), x))

Parset <- function() {
  par(mar=c(2, 2, 2, 1), oma=c(1, 2, 0, 0))
  par(mgp=c(1.8, .2, 0), tck=0.025, las=1)
}

pdf("outputs/production_fig_props.pdf", width=10, height=5)
layout(matrix(1:8, ncol=4, byrow=TRUE))
Parset()
i <- 1
##
for(.var in levels(mass$variable)) {
  .table <- filter(mass, variable==.var)
  .mat <- acast(.table, clabel~meas, fill=0)
  barplot(.mat, ylim=ylims[[.var]], col=colors.C[rownames(.mat)])
  mtext(.var, 3)
}
cex.exp <- c(1.2, .8)
with(list(x=unique(mass$clabel)),
     LegendFig(title="Ctype", legend=x, fill=colors.C[x], ncol=2, border=NA, box.cex=cex.exp))
with(list(x=Relabel(unique(omoc$group),relabel.FG)),
     LegendFig(title="FG", legend=x, fill=colors.FG[x], border=NA, box.cex=cex.exp))
##
for(.var in c("O/C", "H/C", "N/C")) {
  .table <- filter(atomr, variable==.var)
  .mat <- acast(.table, group~meas, fill=0)
  barplot(.mat, ylim=ylims[[.var]], col=colors.FG[Relabel(rownames(.mat),relabel.FG)])
  mtext(.var, 3)
}
##
.mat <- acast(omoc, group~meas, fill=0)
barplot(.mat, ylim=c(0, 1.1), yaxt="n", col=colors.FG[Relabel(rownames(.mat),relabel.FG)])
mtext("OM/OC", 3)
yval <- seq(0, par("usr")[4], .2)
axis(2, yval, sprintf("%.1f", yval+1), cex.axis=1.4)
mtext(c("Ratio", "Recovery fraction"), 2, adj=c(.24, .8), outer=TRUE, las=0)
dev.off()

## -----------------------------------------------------------------------------

osc <- SelectCase(merged.osc) %>%
   filter((meas=="full" & method=="true") | (meas!="full" & method=="approx")) %>%
   mutate(method=NULL)

osc$index <- seq(nrow(osc))

pdf("outputs/production_fig_OSC.pdf", width=7, height=5)
par(mfrow=c(1,1), cex=1.2)
Parset()
with(osc, {
  plot.new()
  plot.window(range(index), c(-4, 3), yaxs="i")
  abline(h=seq(-4, 3), lty=2, col=8)
  abline(h=0)
  lines(index, value, type="h", lwd=2, col="midnightblue")
  points(index, value, pch=19, lwd=2, col="midnightblue")
  axis(1, index, FALSE)
  axis(2)
  axis(3,,FALSE)
  axis(4,,FALSE)
  box()
  text(index, par("usr")[3]-par("cxy")[2]*.3, adj=c(1, .5), xpd=NA, srt=30,
       ifelse(meas=="AMS", expression(2*O/C-H/C), meas))
  mtext(expression(bar(OS)[C]), 2, las=0, line=par("mgp")[1])
})
dev.off()