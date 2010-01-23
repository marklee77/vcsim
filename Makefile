.PHONY: data results reports

data:
	$(MAKE) -C data

results: data/.done

reports: results/.done
