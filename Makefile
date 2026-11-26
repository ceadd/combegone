.PHONY: app deps test clean
app: deps
	./scripts/build-app.sh
deps:
	./scripts/build-deps.sh
test:
	swift test
clean:
	rm -rf build .build vendor
