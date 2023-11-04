![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# Network stats from older to newer commit
## 16 tiles
  - 25.88% 243085um  7918 cells 544 dff, 23.26 min gds, 13.55 viewer    <- 384 synapses (16) x 16 x 8
  - 40.98% 393467um 12384 cells 800 dff, 19.59 min gds,                 <- 640 synapses (16) x 16 x 16 x 8
  - 43.67% 432050um 12932 cells 928 dff, 29.0  min gds, 47.26 viewer    <- 640 synapses (16) x 16 x 16 x 8 fixed the weights
  - 45.23% 427921um 13795 cells 928 dff, 26.5  min gds                  <- 640 synapses (16) x 16 x 16 x 8 **BN added**

  - 17.09% 100777um  5116 cells 808 dff, 15.19 min gds                  <- 320 synapses (16) x 16 x 16 x 8 **50% sparsity!**
  - 24.72% 183035um  7957 cells 968 dff, 13.22 min gds                  <- 320 synapses (16) x 16 x 16 x 8 **BN scale per neuron**, 50% sparsity!

## 8 tiles
  - 49.81%, 185466um 7977 cells 968 dff, 15.45 min gds                  <- 320 synapses (16) x 16 x 16 x 8 BN scale per neuron, 50% sparsity!


# What is Tiny Tapeout?

TinyTapeout is an educational project that aims to make it easier and cheaper than ever to get your digital designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Verilog Projects

Edit the [info.yaml](info.yaml) and uncomment the `source_files` and `top_module` properties, and change the value of `language` to "Verilog". Add your Verilog files to the `src` folder, and list them in the `source_files` property.

The GitHub action will automatically build the ASIC files using [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/).

## How to enable the GitHub actions to build the ASIC files

Please see the instructions for:

- [Enabling GitHub Actions](https://tinytapeout.com/faq/#when-i-commit-my-change-the-gds-action-isnt-running)
- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://discord.gg/rPK2nSjxy8)

## What next?

- Submit your design to the next shuttle [on the website](https://tinytapeout.com/#submit-your-design). The closing date is **November 4th**.
- Edit this [README](README.md) and explain your design, how it works, and how to test it.
- Share your GDS on your social network of choice, tagging it #tinytapeout and linking Matt's profile:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [matt-venn](https://www.linkedin.com/in/matt-venn/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - Twitter [#tinytapeout](https://twitter.com/hashtag/tinytapeout?src=hashtag_click) [@matthewvenn](https://twitter.com/matthewvenn)
