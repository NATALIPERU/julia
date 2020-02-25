## CURL ##

ifeq ($(USE_SYSTEM_LIBSSH2), 0)
$(BUILDDIR)/curl-$(CURL_VER)/build-configured: | $(build_prefix)/manifest/libssh2
endif

ifeq ($(USE_SYSTEM_MBEDTLS), 0)
$(BUILDDIR)/curl-$(CURL_VER)/build-configured: | $(build_prefix)/manifest/mbedtls
endif

ifneq ($(USE_BINARYBUILDER_CURL),1)
CURL_LDFLAGS := $(RPATH_ESCAPED_ORIGIN)

# On older Linuces (those that use OpenSSL < 1.1) we include `libpthread` explicitly.
# It doesn't hurt to include it explicitly elsewhere, so we do so.
ifeq ($(OS),Linux)
CURL_LDFLAGS += -lpthread
endif

$(SRCCACHE)/curl-$(CURL_VER).tar.bz2: | $(SRCCACHE)
	$(JLDOWNLOAD) $@ https://curl.haxx.se/download/curl-$(CURL_VER).tar.bz2

$(SRCCACHE)/curl-$(CURL_VER)/source-extracted: $(SRCCACHE)/curl-$(CURL_VER).tar.bz2
	$(JLCHECKSUM) $<
	cd $(dir $<) && $(TAR) jxf $(notdir $<)
	touch -c $(SRCCACHE)/curl-$(CURL_VER)/configure # old target
	echo 1 > $@

$(BUILDDIR)/curl-$(CURL_VER)/build-configured: $(SRCCACHE)/curl-$(CURL_VER)/source-extracted
	mkdir -p $(dir $@)
	cd $(dir $@) && \
	$(dir $<)/configure $(CONFIGURE_COMMON) --includedir=$(build_includedir) \
		--without-ssl --without-gnutls --without-gssapi --without-zlib \
		--without-libidn --without-libidn2 --without-libmetalink --without-librtmp \
		--without-nghttp2 --without-nss --without-polarssl \
		--without-spnego --without-libpsl --disable-ares \
		--disable-ldap --disable-ldaps --without-zsh-functions-dir \
		--with-libssh2=$(build_prefix) --with-mbedtls=$(build_prefix) \
		CFLAGS="$(CFLAGS) $(CURL_CFLAGS)" LDFLAGS="$(LDFLAGS) $(CURL_LDFLAGS)"
	echo 1 > $@

$(BUILDDIR)/curl-$(CURL_VER)/build-compiled: $(BUILDDIR)/curl-$(CURL_VER)/build-configured
	$(MAKE) -C $(dir $<) $(LIBTOOL_CCLD)
	echo 1 > $@

$(BUILDDIR)/curl-$(CURL_VER)/build-checked: $(BUILDDIR)/curl-$(CURL_VER)/build-compiled
ifeq ($(OS),$(BUILD_OS))
	$(MAKE) -C $(dir $@) check
endif
	echo 1 > $@

$(eval $(call staged-install, \
	curl,curl-$$(CURL_VER), \
	MAKE_INSTALL,$$(LIBTOOL_CCLD),, \
	$$(INSTALL_NAME_CMD)libcurl.$$(SHLIB_EXT) $$(build_shlibdir)/libcurl.$$(SHLIB_EXT)))

clean-curl:
	-rm $(BUILDDIR)/curl-$(CURL_VER)/build-configured $(BUILDDIR)/curl-$(CURL_VER)/build-compiled
	-$(MAKE) -C $(BUILDDIR)/curl-$(CURL_VER) clean

distclean-curl:
	-rm -rf $(SRCCACHE)/curl-$(CURL_VER).tar.bz2 $(SRCCACHE)/curl-$(CURL_VER) $(BUILDDIR)/curl-$(CURL_VER)

get-curl: $(SRCCACHE)/curl-$(CURL_VER).tar.bz2
extract-curl: $(SRCCACHE)/curl-$(CURL_VER)/source-extracted
configure-curl: $(BUILDDIR)/curl-$(CURL_VER)/build-configured
compile-curl: $(BUILDDIR)/curl-$(CURL_VER)/build-compiled
fastcheck-curl: #none
check-curl: $(BUILDDIR)/curl-$(CURL_VER)/build-checked

# If we built our own libcurl, we need to generate a fake LibCURL_jll package to load it in:
$(eval $(call jll-generate,LibCURL_jll,libcurl=libcurl,deac9b47-8bc7-5906-a0fe-35ac56dc84c0,
                           LibSSH2_jll=29816b5a-b9ab-546f-933c-edad1886dfa8 \
						   MbedTLS_jll=c8ffd9c3-330d-5841-b78e-0817d7145fa1 \
						   Zlib_jll=83775a58-1f1d-513f-b197-d71354ab007a))

else # USE_BINARYBUILDER_CURL

# Install LibCURL_jll into our stdlib folder
$(eval $(call stdlib-external,LibCURL_jll,LIBCURL_JLL))
install-curl: install-LibCURL_jll

# Rewrite LibCURL_jll/src/*.jl to avoid dependencies on Pkg
$(eval $(call jll-rewrite,LibCURL_jll))

# Install artifacts from LibCURL_jll into artifacts folder
$(eval $(call artifact-install,LibCURL_jll))

# Fix naming mismatch (libcurl vs. curl)
$(build_prefix)/manifest/curl: $(build_prefix)/manifest/libcurl
	cp "$<" "$@"
install-curl: install-libcurl $(build_prefix)/manifest/curl
UNINSTALL_curl = $(UNINSTALL_libcurl)
uninstall-curl: uninstall-libcurl

endif
