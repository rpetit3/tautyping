#!/usr/bin/env nextflow

//
// RANK CORRELATIONS: Compute a rank correlations between distance matrices, then collate and sort.
//
include { CORRELATIONS_R                       } from '../../modules/local/correlations'
include { CAT_CAT as CAT_SETS                  } from '../../modules/nf-core/cat/cat/main'
include { SORT as SORT_SETS                    } from '../../modules/local/sort'
include { HISTOGRAM_R as HISTOGRAM_SETS        } from '../../modules/local/histogram'

workflow RANK_CORRELATIONS_SETS {

    take:
        ch_matrix1    // REQUIRED channel:  [ meta1, matrix1 ]
		ch_matrix2    // REQUIRED channel:  [ meta2, matrix2 ]   
        ch_method     // REQUIRED channel:  [ correlation    ]
        ch_genes      // REQUIRED channel:  [ meta3, fasta   ]
		
    main:
        ch_correlations = Channel.empty()    
        ch_versions     = Channel.empty()

		// Compute rank correlations for all genes previously computed with PIRATE vs. WGS
        // Note: The Rscript here does handle matrices with different dimensions
        ch_matrix2 = ch_matrix2.join(ch_genes)
		CORRELATIONS_R (
            ch_matrix1, ch_matrix2, ch_method
        )
        ch_correlations = ch_correlations.mix(CORRELATIONS_R.out.correlation)

		// Collate all the individual results into one results file
        ch_correlations.collect{meta, corr -> corr}.map{ corr -> [[id: "sets"], corr]}.set{ ch_merge_correlations }
        ch_sorted = Channel.empty()
        CAT_SETS (
            ch_merge_correlations
        )
        ch_versions = ch_versions.mix(CAT_SETS.out.versions)
        SORT_SETS (
            CAT_SETS.out.file_out
        )
        ch_sorted = ch_sorted.mix(SORT_SETS.out.file_out)
        HISTOGRAM_SETS(
            ch_sorted
        )

    emit:
        correlations       = ch_correlations          // channel: [ [meta], correlations        ]
        sorted_corrs       = ch_sorted                // channel: [ [meta], sorted_all          ]
        png                = HISTOGRAM_SETS.out.png   // channel: [ [meta], png                 ]
        versions           = ch_versions              // channel: [ versions.yml                ]
}