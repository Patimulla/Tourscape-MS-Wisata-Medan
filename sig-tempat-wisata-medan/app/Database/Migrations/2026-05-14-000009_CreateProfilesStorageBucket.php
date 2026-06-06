<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateProfilesStorageBucket extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            INSERT INTO storage.buckets (id, name, public)
            VALUES ('profiles', 'profiles', true)
            ON CONFLICT (id) DO NOTHING;
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_policies
                    WHERE schemaname = 'storage'
                      AND tablename = 'objects'
                      AND policyname = 'Profiles Public Read'
                ) THEN
                    CREATE POLICY "Profiles Public Read"
                    ON storage.objects
                    FOR SELECT
                    TO public
                    USING (bucket_id = 'profiles');
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_policies
                    WHERE schemaname = 'storage'
                      AND tablename = 'objects'
                      AND policyname = 'Profiles Auth Insert Own Folder'
                ) THEN
                    CREATE POLICY "Profiles Auth Insert Own Folder"
                    ON storage.objects
                    FOR INSERT
                    TO authenticated
                    WITH CHECK (
                        bucket_id = 'profiles'
                        AND (storage.foldername(name))[1] = 'admin-mobile'
                        AND (storage.foldername(name))[2] = auth.uid()::text
                    );
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_policies
                    WHERE schemaname = 'storage'
                      AND tablename = 'objects'
                      AND policyname = 'Profiles Auth Update Own Folder'
                ) THEN
                    CREATE POLICY "Profiles Auth Update Own Folder"
                    ON storage.objects
                    FOR UPDATE
                    TO authenticated
                    USING (
                        bucket_id = 'profiles'
                        AND (storage.foldername(name))[1] = 'admin-mobile'
                        AND (storage.foldername(name))[2] = auth.uid()::text
                    )
                    WITH CHECK (
                        bucket_id = 'profiles'
                        AND (storage.foldername(name))[1] = 'admin-mobile'
                        AND (storage.foldername(name))[2] = auth.uid()::text
                    );
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_policies
                    WHERE schemaname = 'storage'
                      AND tablename = 'objects'
                      AND policyname = 'Profiles Auth Delete Own Folder'
                ) THEN
                    CREATE POLICY "Profiles Auth Delete Own Folder"
                    ON storage.objects
                    FOR DELETE
                    TO authenticated
                    USING (
                        bucket_id = 'profiles'
                        AND (storage.foldername(name))[1] = 'admin-mobile'
                        AND (storage.foldername(name))[2] = auth.uid()::text
                    );
                END IF;
            END
            $$;
            SQL,
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $statements = [
            'DROP POLICY IF EXISTS "Profiles Auth Delete Own Folder" ON storage.objects;',
            'DROP POLICY IF EXISTS "Profiles Auth Update Own Folder" ON storage.objects;',
            'DROP POLICY IF EXISTS "Profiles Auth Insert Own Folder" ON storage.objects;',
            'DROP POLICY IF EXISTS "Profiles Public Read" ON storage.objects;',
            "DELETE FROM storage.buckets WHERE id = 'profiles';",
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }
}
