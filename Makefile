VERSION_MAJOR=0
VERSION_MINOR=5
VERSION_PATCH=0
VERSION_NUMBER=$(VERSION_MAJOR)$(VERSION_MINOR)$(VERSION_PATCH)

package:
	zip -r gt_ctc_$(VERSION_NUMBER)_pure gfx models progs sounds
	mv gt_ctc_$(VERSION_NUMBER)_pure.zip gt_ctc_$(VERSION_NUMBER)_pure.pk3
	
install:package
	cp gt_ctc_$(VERSION_NUMBER)_pure.pk3 $(HOME)/.warsow-1.0/basewsw

clean:
	rm gt_ctc_$(VERSION_NUMBER)_pure.pk3
