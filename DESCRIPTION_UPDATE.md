# DESCRIPTION File Updates - Citation Fix

## Changes Made

Updated the DESCRIPTION file to fix citation warnings and improve package metadata.

### What Was Added

#### 1. Authors@R Field (Replaces simple Author field)

**Old:**
```r
Author: Furman IR
```

**New:**
```r
Authors@R: c(
    person("David", "Eubanks", 
           email = "david.eubanks@furman.edu", 
           role = c("aut", "cre"),
           comment = c(ORCID = "YOUR-ORCID-ID-HERE")),
    person("Furman University", 
           role = "cph")
    )
```

**Role Codes:**
- `aut` = Author (who wrote the package)
- `cre` = Creator/Maintainer (current package maintainer)
- `cph` = Copyright holder

**Benefits:**
- Proper author attribution with structured format
- Supports multiple authors/contributors
- Can include ORCID IDs for academic credit
- CRAN-compliant format

#### 2. Date Field

```r
Date: 2025-10-15
```

This fixes the warning: `could not determine year for 'IPEDSR' from package DESCRIPTION file`

The date should be updated each time you release a new version.

#### 3. URL Field

```r
URL: https://github.com/stanislavzza/IPEDSR
```

Provides a link to the package homepage/repository. Shown in:
- Package documentation
- CRAN page (if published)
- Citation information

#### 4. BugReports Field

```r
BugReports: https://github.com/stanislavzza/IPEDSR/issues
```

Tells users where to report bugs. Standard practice for GitHub-hosted packages.

## Citation Output

### Before:
```
To cite package 'IPEDSR' in publications use:

  IR F (????). _IPEDSR: Interface to the IPEDS Database_. R package
  version 0.2.0.

Warning message:
In citation("IPEDSR") :
  could not determine year for 'IPEDSR' from package DESCRIPTION file
```

### After:
```
To cite package 'IPEDSR' in publications use:

  Eubanks D (2025). _IPEDSR: Interface to the IPEDS Database_. R
  package version 0.2.0, <https://github.com/stanislavzza/IPEDSR>.

A BibTeX entry for LaTeX users is

  @Manual{,
    title = {IPEDSR: Interface to the IPEDS Database},
    author = {David Eubanks},
    year = {2025},
    note = {R package version 0.2.0},
    url = {https://github.com/stanislavzza/IPEDSR},
  }
```

✅ **Fixed!** Year is now present, proper author name, includes URL.

## ORCID ID (Optional)

The ORCID placeholder `YOUR-ORCID-ID-HERE` causes a warning. You can:

### Option 1: Add Your Real ORCID
If David Eubanks has an ORCID ID (e.g., `0000-0002-1234-5678`):
```r
comment = c(ORCID = "0000-0002-1234-5678")
```

Get an ORCID at: https://orcid.org/register

### Option 2: Remove ORCID Field
If you don't want to include ORCID:
```r
person("David", "Eubanks", 
       email = "david.eubanks@furman.edu", 
       role = c("aut", "cre"))
```

## Adding Contributors

If others have contributed to the package, add them:

```r
Authors@R: c(
    person("David", "Eubanks", 
           email = "david.eubanks@furman.edu", 
           role = c("aut", "cre")),
    person("Scott", "Contributor",
           role = "ctb"),  # ctb = contributor
    person("Furman University", 
           role = "cph")
    )
```

## Maintenance Notes

### When to Update Date Field

Update the `Date:` field when:
- Releasing a new version
- Submitting to CRAN
- Making significant updates

Format: `YYYY-MM-DD`

### Version Numbering

Current: `0.2.0`

Standard format: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes (e.g., 1.0.0)
- **MINOR**: New features, backward compatible (e.g., 0.3.0)
- **PATCH**: Bug fixes only (e.g., 0.2.1)

With all your recent bug fixes, you might consider bumping to `0.2.1` or `0.3.0` depending on whether you consider the new features (flexible `get_variables()` API) a minor version bump.

## Complete Updated DESCRIPTION

```r
Package: IPEDSR
Type: Package
Title: Interface to the IPEDS Database
Version: 0.2.0
Authors@R: c(
    person("David", "Eubanks", 
           email = "david.eubanks@furman.edu", 
           role = c("aut", "cre"),
           comment = c(ORCID = "YOUR-ORCID-ID-HERE")),
    person("Furman University", 
           role = "cph")
    )
Maintainer: David Eubanks <david.eubanks@furman.edu>
Description: Functions to access and analyze IPEDS (Integrated Postsecondary Education Data System) data. 
    Provides easy-to-use functions for retrieving institutional characteristics, financial data, 
    enrollment statistics, and other higher education metrics. The package automatically manages 
    database setup and updates.
License: MIT + file LICENSE
Encoding: UTF-8
LazyData: true
Date: 2025-10-15
URL: https://github.com/stanislavzza/IPEDSR
BugReports: https://github.com/stanislavzza/IPEDSR/issues
Imports: 
    DBI,
    dplyr,
    duckdb,
    httr,
    magrittr,
    purrr,
    rappdirs,
    rlang,
    rvest,
    stringr,
    tibble,
    tidyr,
    tools,
    utils,
    yaml
Suggests:
    testthat,
    knitr,
    rmarkdown
RoxygenNote: 7.3.3
VignetteBuilder: knitr
```

## References

- [Writing R Extensions - The DESCRIPTION file](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#The-DESCRIPTION-file)
- [R Packages book - DESCRIPTION](https://r-pkgs.org/description.html)
- [ORCID for Researchers](https://orcid.org/)

---

**Status:** ✅ Citation information now works correctly
